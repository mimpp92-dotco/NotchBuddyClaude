import AppKit
import Darwin

/// 감지된 터미널 앱 종류.
enum TerminalApp: String, Sendable {
    case terminal       = "com.apple.Terminal"
    case iterm2         = "com.googlecode.iterm2"
    case vscode         = "com.microsoft.VSCode"
    case cursor         = "com.todesktop.230313mzl4w4u92"
    case warp           = "dev.warp.Warp-Stable"
    case ghostty        = "com.mitchellh.ghostty"
    case zed            = "dev.zed.Zed"
    case claudeDesktop  = "com.anthropic.claudefordesktop"
    case tmux           = "tmux"
    case unknown        = "unknown"

    /// 번들 ID (포커스용). tmux/unknown은 nil.
    var bundleId: String? {
        switch self {
        case .tmux, .unknown: return nil
        default: return rawValue
        }
    }

    /// 표시 이름.
    var displayName: String {
        switch self {
        case .terminal:      return "Terminal"
        case .iterm2:        return "iTerm2"
        case .vscode:        return "VS Code"
        case .cursor:        return "Cursor"
        case .warp:          return "Warp"
        case .ghostty:       return "Ghostty"
        case .zed:           return "Zed"
        case .claudeDesktop: return "Claude"
        case .tmux:          return "tmux"
        case .unknown:       return "Terminal"
        }
    }

    /// SF Symbol 폴백 아이콘.
    var systemIconName: String {
        switch self {
        case .terminal, .iterm2, .warp, .ghostty: return "terminal"
        case .vscode, .cursor, .zed:              return "chevron.left.forwardslash.chevron.right"
        case .claudeDesktop:                      return "brain"
        case .tmux:                               return "rectangle.split.2x1"
        case .unknown:                            return "terminal"
        }
    }

    /// 프로세스 경로에서 앱을 판별하기 위한 키워드 매핑.
    private static let pathMatchers: [(keyword: String, app: TerminalApp)] = [
        ("Terminal.app",             .terminal),
        ("iTerm.app",                .iterm2),
        ("iTerm2.app",               .iterm2),
        ("Visual Studio Code",       .vscode),   // "Visual Studio Code.app", "Visual Studio Code 2.app" 등
        ("Cursor.app",               .cursor),
        ("Warp.app",                 .warp),
        ("Ghostty.app",              .ghostty),
        ("Zed.app",                  .zed),
        ("Claude.app",               .claudeDesktop),
        ("Application Support/Claude/claude-code", .claudeDesktop),
    ]

    /// 프로세스 경로에서 앱을 판별한다.
    static func fromProcessPath(_ path: String) -> TerminalApp? {
        for matcher in pathMatchers {
            if path.contains(matcher.keyword) {
                return matcher.app
            }
        }
        return nil
    }
}

/// 세션의 cwd를 기반으로 터미널 앱을 감지하는 유틸리티.
enum TerminalAppDetector {

    /// 세션을 감지한다. sourcePID가 있으면 정확한 판별, 없으면 cwd 기반 폴백.
    static func detect(cwd: String, sessionId: String? = nil, sourcePID: pid_t? = nil) -> TerminalApp {
        // 1. sourcePID가 있으면 정확한 분류 (HTTP 연결에서 캡처)
        if let pid = sourcePID, pid > 0 {
            // 캡처된 PID가 claude 바이너리가 아닐 수 있음 (훅 전송 자식 프로세스)
            // → 캡처 PID 자체 + 부모 체인에서 claude 프로세스를 찾음
            if let claudePID = findClaudeInChain(startPID: pid) {
                if let path = processPath(pid: claudePID) {
                    let proc = ClaudeProcess(pid: claudePID, path: path)
                    let result = classifyProcess(proc)
                    print("[AppDetector] sourcePID \(pid) → claude PID \(claudePID) → \(result)")
                    return result
                }
            }
            // claude를 못 찾아도 캡처된 PID의 부모 체인으로 앱 판별 시도
            let result = walkParentChain(pid: pid)
            if result != .unknown {
                print("[AppDetector] sourcePID \(pid) → 부모 체인 → \(result)")
                return result
            }
        }

        // 2. sourcePID 없음 → cwd 기반 폴백
        let procs = findClaudeProcesses()
        guard !procs.isEmpty else { return .unknown }

        let candidates = matchProcesses(procs: procs, cwd: cwd)
        if candidates.count == 1 {
            return classifyProcess(candidates[0])
        }

        // 여러 후보: 가장 최근 시작된 프로세스
        let withTime = candidates.map { (proc: $0, startTime: processStartTime(pid: $0.pid)) }
        if let newest = withTime.max(by: { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }) {
            return classifyProcess(newest.proc)
        }

        return candidates.first.map { classifyProcess($0) } ?? .unknown
    }

    /// session_id로 세션 JSONL 파일을 찾고, 그 파일을 열고 있는 PID를 반환.
    private static func findPIDForSessionFile(sessionId: String) -> pid_t? {
        // 1. 세션 파일 찾기: ~/.claude/projects/*/sessions/{sessionId}.jsonl
        let claudeDir = NSHomeDirectory() + "/.claude/projects"
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: claudeDir),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var sessionFile: String?
        let targetName = sessionId + ".jsonl"
        while let url = enumerator.nextObject() as? URL {
            if url.lastPathComponent == targetName {
                sessionFile = url.path
                break
            }
        }

        guard let filePath = sessionFile else { return nil }

        // 2. lsof로 해당 파일을 열고 있는 PID 찾기
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-t", filePath]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }

        // 여러 PID가 나올 수 있음 — claude 프로세스만 필터
        let pids = output.split(separator: "\n").compactMap { pid_t($0) }
        for pid in pids {
            if let path = processPath(pid: pid),
               path.hasSuffix("/claude") || path.contains(".local/share/claude/versions/") || path.contains("/claude-code/") {
                return pid
            }
        }

        return pids.first
    }

    /// 시작 PID에서 자기 자신 + 부모 체인을 올라가며 claude 프로세스를 찾는다.
    private static func findClaudeInChain(startPID: pid_t) -> pid_t? {
        var current = startPID
        for _ in 0..<20 {
            if let path = processPath(pid: current) {
                if path.hasSuffix("/claude") ||
                   path.contains(".local/share/claude/versions/") ||
                   path.contains("/claude-code/") ||
                   path.contains(".vscode/extensions/") {
                    return current
                }
            }
            guard let ppid = parentPID(of: current), ppid > 1 else { break }
            current = ppid
        }
        return nil
    }

    /// 프로세스의 시작 시간을 반환한다.
    private static func processStartTime(pid: pid_t) -> Date? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return nil }
        let tv = info.kp_proc.p_starttime
        return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000)
    }

    /// 프로세스 경로 기반으로 앱을 분류한다.
    /// 바이너리 경로 자체로 앱을 직접 판별 → 일반 CLI만 부모 체인 역추적.
    private static func classifyProcess(_ proc: ClaudeProcess) -> TerminalApp {
        let path = proc.path

        // Claude Desktop: Application Support/Claude/claude-code 또는 Claude.app 내부
        if path.contains("Application Support/Claude/claude-code") ||
           path.contains("Claude.app") {
            return .claudeDesktop
        }

        // VS Code 확장 내 claude 바이너리
        if path.contains(".vscode/extensions/") || path.contains(".vscode-server/") {
            return .vscode
        }

        // Cursor 확장 내 claude 바이너리
        if path.contains(".cursor/extensions/") || path.contains(".cursor-server/") {
            return .cursor
        }

        // 일반 CLI (.local/share/claude/versions/ 등): 부모 체인 역추적
        return walkParentChain(pid: proc.pid)
    }

    private struct ClaudeProcess {
        let pid: pid_t
        let path: String
    }

    // MARK: - Private

    /// 실행 중인 모든 claude 프로세스 PID + 경로를 반환한다.
    /// CLI claude: ~/.local/share/claude/versions/{version} (프로세스명이 버전명)
    /// Desktop claude: ~/Library/Application Support/Claude/claude-code/{version}/claude.app/.../claude
    private static func findClaudeProcesses() -> [ClaudeProcess] {
        let bufferSize = proc_listallpids(nil, 0)
        guard bufferSize > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(bufferSize))
        let count = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * pids.count))
        guard count > 0 else { return [] }

        var result: [ClaudeProcess] = []
        for i in 0..<Int(count) {
            let pid = pids[i]
            guard pid > 0 else { continue }
            guard let path = processPath(pid: pid) else { continue }

            let isClaude =
                path.hasSuffix("/claude") ||                          // Claude Desktop 내부
                path.contains(".local/share/claude/versions/") ||     // CLI (버전 바이너리)
                path.contains("/claude-code/")                        // Claude Desktop 변형

            if isClaude {
                result.append(ClaudeProcess(pid: pid, path: path))
            }
        }
        return result
    }

    /// cwd가 일치하는 프로세스를 모두 반환한다.
    private static func matchProcesses(procs: [ClaudeProcess], cwd: String) -> [ClaudeProcess] {
        guard !cwd.isEmpty else { return [] }

        // 정확한 cwd 매칭
        let exact = procs.filter { proc in
            if let pidCwd = getCwd(pid: proc.pid), pidCwd == cwd { return true }
            return false
        }
        if !exact.isEmpty { return exact }

        // 폴더명만 비교 (폴백)
        let folderName = (cwd as NSString).lastPathComponent
        return procs.filter { proc in
            if let pidCwd = getCwd(pid: proc.pid),
               (pidCwd as NSString).lastPathComponent == folderName { return true }
            return false
        }
    }

    /// PID의 부모 체인을 최대 20레벨까지 역추적하여 앱을 찾는다.
    private static func walkParentChain(pid: pid_t) -> TerminalApp {
        var current = pid
        for _ in 0..<20 {
            guard let ppid = parentPID(of: current), ppid > 1 else { break }

            // 부모 프로세스 이름 확인
            if let path = processPath(pid: ppid) {
                // tmux 감지
                if path.contains("tmux") {
                    return .tmux
                }
                // 앱 감지
                if let app = TerminalApp.fromProcessPath(path) {
                    return app
                }
            }

            current = ppid
        }
        return .unknown
    }

    /// proc_pidpath로 프로세스 실행 경로를 반환한다.
    private static func processPath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let ret = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard ret > 0 else { return nil }
        return String(cString: buffer)
    }

    /// sysctl로 부모 PID를 반환한다.
    private static func parentPID(of pid: pid_t) -> pid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let ret = sysctl(&mib, 4, &info, &size, nil, 0)
        guard ret == 0 else { return nil }
        let ppid = info.kp_eproc.e_ppid
        return ppid > 0 ? ppid : nil
    }

    /// proc_pidinfo로 프로세스의 cwd를 반환한다.
    private static func getCwd(pid: pid_t) -> String? {
        var pathInfo = proc_vnodepathinfo()
        let size = MemoryLayout<proc_vnodepathinfo>.size
        let ret = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &pathInfo, Int32(size))
        guard ret == size else { return nil }
        return withUnsafePointer(to: pathInfo.pvi_cdir.vip_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(cString: $0)
            }
        }
    }
}
