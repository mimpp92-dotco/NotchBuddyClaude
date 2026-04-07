import Foundation
import Network

/// Claude Code HTTP 훅 이벤트.
struct HookEvent: Sendable {
    let hookEventName: String
    let toolName: String?
    let sessionId: String?
    let cwd: String?
    let timestamp: Date
    let sourcePID: pid_t?  // 훅을 보낸 claude 프로세스의 PID

    init(json: [String: Any], sourcePID: pid_t? = nil) {
        self.hookEventName = json["hook_event_name"] as? String
            ?? json["event"] as? String
            ?? "unknown"
        self.toolName = json["tool_name"] as? String
        self.sessionId = json["session_id"] as? String
        self.cwd = json["cwd"] as? String
        self.timestamp = Date()
        self.sourcePID = sourcePID
    }
}

/// Claude Code에서 HTTP POST로 전송하는 훅 이벤트를 수신하는 서버.
/// Network.framework의 NWListener를 사용한다.
@MainActor
final class HookServer {

    private var listener: NWListener?
    private let port: UInt16

    /// 이벤트 수신 시 호출
    var onEvent: (@Sendable (HookEvent) -> Void)?

    init(port: UInt16 = 31982) {
        self.port = port
    }

    /// 서버를 시작한다.
    func start() {
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("[HookServer] 리스너 생성 실패: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.handleConnection(connection)
            }
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[HookServer] 포트 \(self.port)에서 대기 중")
            case .failed(let error):
                print("[HookServer] 실패: \(error)")
            default:
                break
            }
        }

        listener?.start(queue: .main)
    }

    /// 서버를 중지한다.
    func stop() {
        listener?.cancel()
        listener = nil
        print("[HookServer] 중지됨")
    }

    // MARK: - PID 캡처

    /// 우리 서버 포트에 연결된 클라이언트 PID를 찾는다.
    /// receive 콜백 내부에서 호출 — 이 시점에 TCP 연결이 확실히 활성.
    nonisolated private static func captureSourcePID(serverPort: UInt16) -> pid_t? {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        // 우리 서버 포트에 ESTABLISHED 연결이 있는 프로세스 찾기
        process.arguments = ["-i", "TCP:\(serverPort)", "-sTCP:ESTABLISHED", "-t", "-n", "-P"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else {
            return nil
        }

        // 여러 PID 중 우리 앱(NotchBuddy) 자신은 제외
        let myPID = ProcessInfo.processInfo.processIdentifier
        let pids = output.split(separator: "\n").compactMap { pid_t($0) }.filter { $0 != myPID }
        return pids.first
    }

    // MARK: - 연결 처리

    private func handleConnection(_ connection: NWConnection) {
        let serverPort = self.port
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
            // 연결 활성 상태에서 소스 PID 캡처
            let sourcePID = Self.captureSourcePID(serverPort: serverPort)

            // HTTP 200 응답 전송 후 연결 종료
            let response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })

            guard let data = data, error == nil else { return }
            guard let raw = String(data: data, encoding: .utf8) else { return }

            // HTTP 바디 추출 (헤더와 빈 줄로 구분)
            guard let bodyRange = raw.range(of: "\r\n\r\n") else { return }
            let body = String(raw[bodyRange.upperBound...])
            guard !body.isEmpty else { return }

            // JSON 파싱
            guard let bodyData = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
                return
            }

            let event = HookEvent(json: json, sourcePID: sourcePID)
            print("[HookServer] 이벤트 수신: \(event.hookEventName) (PID: \(sourcePID.map(String.init) ?? "?"))")

            Task { @MainActor [weak self] in
                self?.onEvent?(event)
            }
        }
    }
}
