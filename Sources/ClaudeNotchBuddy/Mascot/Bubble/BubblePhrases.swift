/// 상태별 말풍선 문구와 랜덤 중얼중얼 문구를 관리한다.
/// AppLanguage.saved에 따라 적절한 언어 문구를 반환한다.
enum BubblePhrases {

    /// 상태별 고정 문구. nil이면 말풍선 없음.
    static func text(for state: MascotState) -> String? {
        let lang = AppLanguage.saved
        switch state {
        case .working:    return phrases(lang, working).randomElement()
        case .needsInput: return phrases(lang, needsInput).randomElement()
        case .done:       return phrases(lang, done).randomElement()
        case .error:      return phrases(lang, error).randomElement()
        default:          return nil
        }
    }

    static func needsInputPhrase() -> String {
        phrases(AppLanguage.saved, needsInput).randomElement()!
    }

    static func workingPhrase() -> String {
        phrases(AppLanguage.saved, working).randomElement()!
    }

    static func randomPlayingPhrase() -> String {
        phrases(AppLanguage.saved, playing).randomElement()!
    }

    static func randomIdlePhrase() -> String {
        phrases(AppLanguage.saved, idle).randomElement()!
    }

    // MARK: - 언어별 문구 선택

    private static func phrases(_ lang: AppLanguage, _ set: [AppLanguage: [String]]) -> [String] {
        set[lang] ?? set[.en]!
    }

    // MARK: - Working

    private static let working: [AppLanguage: [String]] = [
        .ko: ["🔥", "집중!", "코딩 중~", "열심히!", "💻", "⚡", "타닥타닥", "작업 중...", "🛠️", "삐빅삐빅",
              "분석 중~", "🧠", "생각 중...", "거의 다!", "⏳", "뚝딱뚝딱", "🚀", "좋아좋아", "읽는 중...", "✍️"],
        .en: ["🔥", "Focus!", "Coding~", "On it!", "💻", "⚡", "Tap tap", "Working...", "🛠️", "Beep boop",
              "Analyzing~", "🧠", "Thinking...", "Almost!", "⏳", "Building!", "🚀", "Nice nice", "Reading...", "✍️"],
        .ja: ["🔥", "集中!", "コーディング中~", "頑張る!", "💻", "⚡", "カタカタ", "作業中...", "🛠️", "ピコピコ",
              "分析中~", "🧠", "考え中...", "もう少し!", "⏳", "トントン", "🚀", "いいね!", "読み中...", "✍️"],
        .zh: ["🔥", "专注!", "编码中~", "加油!", "💻", "⚡", "啪嗒啪嗒", "工作中...", "🛠️", "滴滴答答",
              "分析中~", "🧠", "思考中...", "快好了!", "⏳", "叮叮当当", "🚀", "不错不错", "阅读中...", "✍️"],
    ]

    // MARK: - NeedsInput

    private static let needsInput: [AppLanguage: [String]] = [
        .ko: ["확인해줘!", "여기 봐!", "입력 필요!", "기다리는 중..", "❓", "저기요~", "잠깐만!",
              "🔔", "도움 필요!", "응답해줘~", "👋", "여기여기!", "⚠️", "멈췄어요!", "🙋"],
        .en: ["Check this!", "Look here!", "Need input!", "Waiting..", "❓", "Hey~", "Hold on!",
              "🔔", "Need help!", "Respond~", "👋", "Over here!", "⚠️", "Stuck!", "🙋"],
        .ja: ["確認して!", "ここ見て!", "入力必要!", "待ってる..", "❓", "あの~", "ちょっと!",
              "🔔", "助けて!", "返事して~", "👋", "ここここ!", "⚠️", "止まった!", "🙋"],
        .zh: ["看看这里!", "检查一下!", "需要输入!", "等待中..", "❓", "那个~", "等一下!",
              "🔔", "需要帮助!", "回复我~", "👋", "这里这里!", "⚠️", "卡住了!", "🙋"],
    ]

    // MARK: - Done

    private static let done: [AppLanguage: [String]] = [
        .ko: ["완료!", "다 했어!", "끝~!", "🎉", "성공!", "짜잔~", "✅", "해냈다!",
              "완벽!", "🏆", "굿굿!", "마무리~", "🌟", "대성공!", "👏"],
        .en: ["Done!", "Finished!", "All set~!", "🎉", "Success!", "Ta-da~", "✅", "Nailed it!",
              "Perfect!", "🏆", "Good good!", "Wrapped up~", "🌟", "Great job!", "👏"],
        .ja: ["完了!", "できた!", "終わり~!", "🎉", "成功!", "じゃじゃーん~", "✅", "やった!",
              "完璧!", "🏆", "よしよし!", "おしまい~", "🌟", "大成功!", "👏"],
        .zh: ["完成!", "搞定了!", "结束~!", "🎉", "成功!", "当当当~", "✅", "做到了!",
              "完美!", "🏆", "好好!", "收工~", "🌟", "大成功!", "👏"],
    ]

    // MARK: - Error

    private static let error: [AppLanguage: [String]] = [
        .ko: ["으악!", "에러!", "문제 발생!", "💥", "앗...", "실패ㅠ", "❌", "이런...",
              "고장났다!", "🔴", "뭔가 잘못됐어", "헉!", "⚡오류", "크래시!", "😱"],
        .en: ["Oops!", "Error!", "Problem!", "💥", "Oh no...", "Failed..", "❌", "Uh oh...",
              "Broken!", "🔴", "Something wrong", "Yikes!", "⚡Bug", "Crash!", "😱"],
        .ja: ["うわぁ!", "エラー!", "問題発生!", "💥", "あっ...", "失敗..", "❌", "あれ...",
              "壊れた!", "🔴", "何かおかしい", "ひぇ!", "⚡バグ", "クラッシュ!", "😱"],
        .zh: ["糟糕!", "出错了!", "有问题!", "💥", "哎呀...", "失败了..", "❌", "这...",
              "坏了!", "🔴", "出了点问题", "天呐!", "⚡Bug", "崩溃了!", "😱"],
    ]

    // MARK: - Playing

    private static let playing: [AppLanguage: [String]] = [
        .ko: ["심심하다~", "뭐하지...", "코드 짜고 싶다!", "냥~", "졸려...", "🎵", "☕",
              "오늘 날씨 좋다", "버그 없는 세상...", "리팩토링하고 싶어", "테스트 통과!", "커밋 푸시~",
              "PR 올려야지", "디버깅 중...", "컴파일 성공!", "☀️", "🌙", "흠...", "🎮",
              "산책 가고 싶다", "🍕", "간식 타임~", "🎧", "음악 듣는 중~", "🌈", "무지개다!",
              "🐱", "고양이 보고 싶다", "✨", "반짝반짝", "🧹", "정리 좀 해야지",
              "📚", "공부할까...", "배고프다~", "🍜"],
        .en: ["Bored~", "What to do...", "Wanna code!", "Meow~", "Sleepy...", "🎵", "☕",
              "Nice weather", "No bugs world...", "Wanna refactor", "Tests passed!", "Git push~",
              "PR time", "Debugging...", "Build success!", "☀️", "🌙", "Hmm...", "🎮",
              "Wanna walk", "🍕", "Snack time~", "🎧", "Listening~", "🌈", "Rainbow!",
              "🐱", "Miss my cat", "✨", "Sparkle", "🧹", "Should clean up",
              "📚", "Study?...", "Hungry~", "🍜"],
        .ja: ["暇だな~", "何しよう...", "コード書きたい!", "にゃ~", "眠い...", "🎵", "☕",
              "いい天気", "バグのない世界...", "リファクタしたい", "テスト通った!", "コミット~",
              "PR出そう", "デバッグ中...", "ビルド成功!", "☀️", "🌙", "うーん...", "🎮",
              "散歩したい", "🍕", "おやつタイム~", "🎧", "音楽聴いてる~", "🌈", "虹だ!",
              "🐱", "猫に会いたい", "✨", "キラキラ", "🧹", "片付けなきゃ",
              "📚", "勉強しよう...", "お腹すいた~", "🍜"],
        .zh: ["好无聊~", "干嘛呢...", "想写代码!", "喵~", "好困...", "🎵", "☕",
              "天气真好", "没有Bug的世界...", "想重构", "测试通过!", "提交代码~",
              "发PR", "调试中...", "编译成功!", "☀️", "🌙", "嗯...", "🎮",
              "想散步", "🍕", "零食时间~", "🎧", "听音乐~", "🌈", "彩虹!",
              "🐱", "想撸猫", "✨", "闪闪发光", "🧹", "该整理了",
              "📚", "学习吧...", "饿了~", "🍜"],
    ]

    // MARK: - Idle

    private static let idle: [AppLanguage: [String]] = [
        .ko: ["zZZ", "...", "💤", "zzz", "쿨쿨", "😴", "꿈나라~", "코~", "하암...", "🌙", "좋은 꿈...", "스르륵"],
        .en: ["zZZ", "...", "💤", "zzz", "Snore~", "😴", "Dreamland~", "Zzz~", "Yawn...", "🌙", "Sweet dreams", "Dozing"],
        .ja: ["zZZ", "...", "💤", "zzz", "すやすや", "😴", "夢の中~", "グー", "ふわぁ...", "🌙", "いい夢...", "うとうと"],
        .zh: ["zZZ", "...", "💤", "zzz", "呼噜噜", "😴", "梦乡~", "呼~", "哈欠...", "🌙", "好梦...", "迷迷糊糊"],
    ]
}
