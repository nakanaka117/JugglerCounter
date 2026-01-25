import SwiftUI
import WebKit

// MARK: - デザインシステム
struct AppColors {
    static let background = Color(red: 0.06, green: 0.06, blue: 0.08)
    static let cardBackground = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let cardBackgroundLight = Color(red: 0.16, green: 0.16, blue: 0.18)
    static let accent = Color(red: 0.4, green: 0.8, blue: 1.0) // シアン
    static let bb = Color(red: 1.0, green: 0.3, blue: 0.35)
    static let rb = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let cherry = Color(red: 0.95, green: 0.2, blue: 0.5)
    static let grape = Color(red: 0.3, green: 0.85, blue: 0.4)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let divider = Color.white.opacity(0.1)
}

// MARK: - 子役の種類を定義
enum CoinType: String, CaseIterable, Identifiable {
    case bigSingle = "単独BB"
    case bigOverlap = "重複BB"
    case bigUnknown = "不明BB"
    case regSingle = "単独RB"
    case regOverlap = "重複RB"
    case regUnknown = "不明RB"
    case cherry = "チェリー"
    case grape = "ブドウ"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .bigSingle, .bigOverlap, .bigUnknown: return AppColors.bb
        case .regSingle, .regOverlap, .regUnknown: return AppColors.rb
        case .cherry: return AppColors.cherry
        case .grape: return AppColors.grape
        }
    }
    
    var shortName: String {
        switch self {
        case .bigSingle: return "単独"
        case .bigOverlap: return "重複"
        case .bigUnknown: return "不明"
        case .regSingle: return "単独"
        case .regOverlap: return "重複"
        case .regUnknown: return "不明"
        case .cherry: return "チェリー"
        case .grape: return "ブドウ"
        }
    }
    
    var iconName: String? {
        switch self {
        case .bigSingle, .bigOverlap, .bigUnknown: return "bb_icon"
        case .regSingle, .regOverlap, .regUnknown: return "rb_icon"
        default: return nil
        }
    }
    
    var buttonAssetImage: String? {
        switch self {
        case .cherry: return "cherry"
        case .grape: return "grape"
        default: return nil
        }
    }
    
    var isTextButton: Bool {
        switch self {
        case .bigSingle, .bigOverlap, .bigUnknown, .regSingle, .regOverlap, .regUnknown:
            return true
        default:
            return false
        }
    }
    
    enum Group: Equatable {
        case bb, rb, koyaku
    }
    
    var group: Group {
        switch self {
        case .bigSingle, .bigOverlap, .bigUnknown: return .bb
        case .regSingle, .regOverlap, .regUnknown: return .rb
        case .cherry, .grape: return .koyaku
        }
    }
}

// MARK: - データ構造
struct CounterItem: Identifiable, Hashable {
    let id = UUID()
    let type: CoinType
    var count: Int = 0
}

struct ActionLog: Identifiable {
    let id = UUID()
    let type: CoinType
    let timestamp: Date
}

struct GameSession: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    var endDate: Date
    var totalSpins: Int
    var counters: [String: Int]
    // 初期入力データ
    var initialSpins: Int
    var initialBB: Int
    var initialRB: Int
    // メモ
    var memo: String
    
    init(id: UUID = UUID(), startDate: Date = Date(), endDate: Date = Date(), totalSpins: Int = 0, counters: [String: Int] = [:], initialSpins: Int = 0, initialBB: Int = 0, initialRB: Int = 0, memo: String = "") {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.totalSpins = totalSpins
        self.counters = counters
        self.initialSpins = initialSpins
        self.initialBB = initialBB
        self.initialRB = initialRB
        self.memo = memo
    }
    
    var bbTotal: Int {
        (counters[CoinType.bigSingle.rawValue] ?? 0) +
        (counters[CoinType.bigOverlap.rawValue] ?? 0) +
        (counters[CoinType.bigUnknown.rawValue] ?? 0)
    }
    
    var rbTotal: Int {
        (counters[CoinType.regSingle.rawValue] ?? 0) +
        (counters[CoinType.regOverlap.rawValue] ?? 0) +
        (counters[CoinType.regUnknown.rawValue] ?? 0)
    }
    
    var combinedRate: String {
        let total = bbTotal + rbTotal
        let games = max(totalSpins, 1)
        let rate = Double(games) / Double(max(total, 1))
        return String(format: "1/%.0f", rate)
    }
}

// MARK: - メインビュー
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var gameSessions: [GameSession] = []
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GameHistoryView(gameSessions: $gameSessions)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("ホーム")
                }
                .tag(0)
            
            SettingJudgmentView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("設定判別")
                }
                .tag(1)
            
            BrowserView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("ブラウザ")
                }
                .tag(2)
        }
        .preferredColorScheme(.dark)
        .tint(AppColors.accent)
    }
}

// MARK: - ゲーム履歴画面
struct GameHistoryView: View {
    @Binding var gameSessions: [GameSession]
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ヘッダーカード
                    VStack(spacing: 12) {
                        // ロゴ/タイトルエリア
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("JUGGLER")
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [AppColors.accent, AppColors.accent.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                Text("COUNTER")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .tracking(3)
                            }
                            Spacer()
                            
                            // 統計サマリー
                            if !gameSessions.isEmpty {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("総セッション")
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.textSecondary)
                                    Text("\(gameSessions.count)")
                                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                                        .foregroundStyle(AppColors.accent)
                                }
                            }
                        }
                        
                        // 新規ゲームボタン
                        Button {
                            navigationPath.append("initialInput")
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.accent)
                                        .frame(width: 40, height: 40)
                                        .shadow(color: AppColors.accent.opacity(0.4), radius: 6, x: 0, y: 3)
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("新規ゲーム開始")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text("タップしてカウンターを開始")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(AppColors.accent)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AppColors.cardBackgroundLight)
                                    .shadow(color: AppColors.accent.opacity(0.2), radius: 8, x: 0, y: 4)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppColors.accent.opacity(0.4), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(PressableButtonStyle(color: AppColors.accent))
                    }
                    .padding(16)
                    .background(
                        AppColors.cardBackground
                            .clipShape(
                                .rect(bottomLeadingRadius: 20, bottomTrailingRadius: 20)
                            )
                    )
                    
                    // 履歴リスト
                    if gameSessions.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(AppColors.cardBackground)
                                    .frame(width: 80, height: 80)
                                Image(systemName: "tray")
                                    .font(.system(size: 32))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            
                            VStack(spacing: 6) {
                                Text("履歴がありません")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textPrimary)
                                Text("上のボタンから\n新規ゲームを開始してください")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(gameSessions.sorted(by: { $0.endDate > $1.endDate }), id: \.id) { session in
                                    Button {
                                        navigationPath.append(session.id)
                                    } label: {
                                        ImprovedGameSessionRow(session: session)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { destination in
                if destination == "initialInput" {
                    InitialInputView(gameSessions: $gameSessions, navigationPath: $navigationPath)
                }
            }
            .navigationDestination(for: UUID.self) { sessionId in
                if let session = gameSessions.first(where: { $0.id == sessionId }) {
                    CounterView(gameSessions: $gameSessions, existingSession: session, navigationPath: $navigationPath)
                }
            }
            .navigationDestination(for: InitialInputView.InitialGameData.self) { data in
                CounterView(gameSessions: $gameSessions, initialData: data, navigationPath: $navigationPath)
            }
        }
    }
}

// MARK: - 初期入力画面（ゲーム数・BB・RB入力）
struct InitialInputView: View {
    @Binding var gameSessions: [GameSession]
    @Binding var navigationPath: NavigationPath
    
    @State private var initialSpins: String = ""
    @State private var initialBB: String = ""
    @State private var initialRB: String = ""
    
    struct InitialGameData: Hashable {
        var spins: Int
        var bb: Int
        var rb: Int
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // ヘッダー
                VStack(spacing: 4) {
                    Text("初期データ入力")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("途中から始める場合は現在の値を入力")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.top, 10)
                
                VStack(spacing: 14) {
                    // 総ゲーム数
                    InputRow(
                        label: "総ゲーム数",
                        value: $initialSpins,
                        placeholder: "0",
                        color: AppColors.grape,
                        icon: "gamecontroller.fill"
                    )
                    
                    // BB回数
                    InputRow(
                        label: "BB回数",
                        value: $initialBB,
                        placeholder: "0",
                        color: AppColors.bb,
                        icon: "7.circle.fill"
                    )
                    
                    // RB回数
                    InputRow(
                        label: "RB回数",
                        value: $initialRB,
                        placeholder: "0",
                        color: AppColors.rb,
                        icon: "b.circle.fill"
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // ボタンエリア
                VStack(spacing: 10) {
                    // スタートボタン
                    Button {
                        let spins = Int(initialSpins) ?? 0
                        let bb = Int(initialBB) ?? 0
                        let rb = Int(initialRB) ?? 0
                        let data = InitialGameData(spins: spins, bb: bb, rb: rb)
                        // 初期入力画面を置き換えてカウンター画面へ
                        navigationPath.removeLast()
                        navigationPath.append(data)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("ゲーム開始")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.accent)
                                .shadow(color: AppColors.accent.opacity(0.4), radius: 6, x: 0, y: 3)
                        )
                    }
                    .buttonStyle(PressableButtonStyle(color: AppColors.accent))
                    
                    // スキップリンク
                    Button {
                        let data = InitialGameData(spins: 0, bb: 0, rb: 0)
                        navigationPath.removeLast()
                        navigationPath.append(data)
                    } label: {
                        Text("スキップして0から開始")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("新規ゲーム")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    navigationPath.removeLast()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("戻る")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(AppColors.accent)
                }
            }
        }
        .toolbarBackground(AppColors.cardBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

// MARK: - 入力行コンポーネント
struct InputRow: View {
    let label: String
    @Binding var value: String
    let placeholder: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            // アイコン
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
            }
            
            // ラベル
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            // 入力フィールド
            TextField(placeholder, text: $value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .foregroundStyle(color)
                .frame(width: 100)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.cardBackgroundLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(color.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.cardBackground)
        )
    }
}

// MARK: - 改善されたセッション行
struct ImprovedGameSessionRow: View {
    let session: GameSession
    
    var body: some View {
        HStack(spacing: 12) {
            // 日付インジケーター
            VStack(spacing: 2) {
                Text(session.startDate, format: .dateTime.day())
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text(session.startDate, format: .dateTime.month(.abbreviated))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .textCase(.uppercase)
            }
            .frame(width: 44)
            
            // 区切り線
            Rectangle()
                .fill(AppColors.divider)
                .frame(width: 1, height: 40)
            
            // メイン情報
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    // ゲーム数
                    HStack(spacing: 3) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.grape)
                        Text("\(session.totalSpins)G")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppColors.grape)
                    }
                    
                    // 合算
                    HStack(spacing: 3) {
                        Image(systemName: "sum")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.accent)
                        Text(session.combinedRate)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppColors.accent)
                    }
                }
                
                // BB/RB詳細
                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        Text("BB")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppColors.bb)
                        Text("\(session.bbTotal)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    
                    HStack(spacing: 3) {
                        Text("RB")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppColors.rb)
                        Text("\(session.rbTotal)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // タップ促進アイコン
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.accent)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.cardBackground)
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.divider, lineWidth: 1)
        )
    }
}

// MARK: - 改善されたカウンター画面
struct CounterView: View {
    @Binding var gameSessions: [GameSession]
    @Binding var navigationPath: NavigationPath
    
    var existingSession: GameSession?
    var initialData: InitialInputView.InitialGameData?
    
    @State private var items: [CounterItem] = []
    @State private var totalSpins: Int = 0
    @State private var logs: [ActionLog] = []
    @State private var sessionId = UUID()
    @State private var sessionStartDate = Date()
    @State private var showResetAlert = false
    @State private var showSpinInput = false
    
    // 初期入力データを保持
    @State private var startSpins: Int = 0
    @State private var startBB: Int = 0
    @State private var startRB: Int = 0
    
    // メモ
    @State private var memo: String = ""
    
    // フラッシュエフェクト用
    @State private var flashColor: Color = .clear
    @State private var showFlash = false
    
    init(gameSessions: Binding<[GameSession]>, existingSession: GameSession? = nil, initialData: InitialInputView.InitialGameData? = nil, navigationPath: Binding<NavigationPath>) {
        self._gameSessions = gameSessions
        self.existingSession = existingSession
        self.initialData = initialData
        self._navigationPath = navigationPath
    }
    
    // 計算プロパティ
    private var bbTotal: Int {
        let single = items.first(where: { $0.type == .bigSingle })?.count ?? 0
        let overlap = items.first(where: { $0.type == .bigOverlap })?.count ?? 0
        let unknown = items.first(where: { $0.type == .bigUnknown })?.count ?? 0
        return single + overlap + unknown
    }
    
    private var rbTotal: Int {
        let single = items.first(where: { $0.type == .regSingle })?.count ?? 0
        let overlap = items.first(where: { $0.type == .regOverlap })?.count ?? 0
        let unknown = items.first(where: { $0.type == .regUnknown })?.count ?? 0
        return single + overlap + unknown
    }
    
    private var combinedTotal: Int { bbTotal + rbTotal }
    
    // 単独・重複用の実効ゲーム数（初期ゲーム数を引いた値）
    private var effectiveSpins: Int {
        max(totalSpins - startSpins, 0)
    }
    
    private func saveSession() {
        var counters: [String: Int] = [:]
        for item in items {
            counters[item.type.rawValue] = item.count
        }
        
        let session = GameSession(
            id: sessionId,
            startDate: sessionStartDate,
            endDate: Date(),
            totalSpins: totalSpins,
            counters: counters,
            initialSpins: startSpins,
            initialBB: startBB,
            initialRB: startRB,
            memo: memo
        )
        
        if let index = gameSessions.firstIndex(where: { $0.id == sessionId }) {
            gameSessions[index] = session
        } else {
            gameSessions.append(session)
        }
    }

    private func increment(_ type: CoinType) {
        if let idx = items.firstIndex(where: { $0.type == type }) {
            items[idx].count += 1
            logs.append(ActionLog(type: type, timestamp: Date()))
            
            // フラッシュエフェクト
            triggerFlash(color: type.color)
            
            // 触覚フィードバック
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    private func triggerFlash(color: Color) {
        flashColor = color
        withAnimation(.easeIn(duration: 0.08)) {
            showFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.15)) {
                showFlash = false
            }
        }
    }

    private func decrement(_ type: CoinType) {
        if let idx = items.firstIndex(where: { $0.type == type }), items[idx].count > 0 {
            items[idx].count -= 1
        }
    }

    private func undoLast() {
        guard let last = logs.popLast(), let idx = items.firstIndex(where: { $0.type == last.type }) else { return }
        if items[idx].count > 0 { items[idx].count -= 1 }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    private func resetAll() {
        for i in items.indices { items[i].count = 0 }
        totalSpins = 0
        logs.removeAll()
    }
    
    private func loadExistingSession() {
        if let session = existingSession {
            // 既存セッションを読み込み
            sessionId = session.id
            sessionStartDate = session.startDate
            totalSpins = session.totalSpins
            startSpins = session.initialSpins
            startBB = session.initialBB
            startRB = session.initialRB
            memo = session.memo
            items = CoinType.allCases.map { type in
                let count = session.counters[type.rawValue] ?? 0
                return CounterItem(type: type, count: count)
            }
        } else if let data = initialData {
            // 初期データから新規セッション
            items = CoinType.allCases.map { CounterItem(type: $0, count: 0) }
            totalSpins = data.spins
            startSpins = data.spins
            startBB = data.bb
            startRB = data.rb
            // BB/RBは不明に割り当て
            if let bbIdx = items.firstIndex(where: { $0.type == .bigUnknown }) {
                items[bbIdx].count = data.bb
            }
            if let rbIdx = items.firstIndex(where: { $0.type == .regUnknown }) {
                items[rbIdx].count = data.rb
            }
        } else {
            // 完全新規
            items = CoinType.allCases.map { CounterItem(type: $0, count: 0) }
        }
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ステータスヘッダー
                StatusHeaderView(
                    totalSpins: totalSpins,
                    bbTotal: bbTotal,
                    rbTotal: rbTotal,
                    combinedTotal: combinedTotal,
                    startSpins: startSpins,
                    startBB: startBB,
                    startRB: startRB,
                    onSpinTap: { showSpinInput = true }
                )
                
                // ヘッダーとコンテンツの間の空白
                Rectangle()
                    .fill(AppColors.background)
                    .frame(height: 8)
                
                // メインカウンターエリア
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // BB セクション
                        BonusSection(
                            title: "BIG BONUS",
                            color: AppColors.bb,
                            items: items.filter { $0.type.group == .bb },
                            totalSpins: totalSpins,
                            effectiveSpins: effectiveSpins,
                            increment: increment
                        )
                        
                        // RB セクション
                        BonusSection(
                            title: "REG BONUS",
                            color: AppColors.rb,
                            items: items.filter { $0.type.group == .rb },
                            totalSpins: totalSpins,
                            effectiveSpins: effectiveSpins,
                            increment: increment
                        )
                        
                        // 小役セクション（チェリー・ブドウ）
                        KoyakuSection(
                            items: items.filter { $0.type.group == .koyaku },
                            totalSpins: effectiveSpins,
                            increment: increment
                        )
                        
                        // メモ欄
                        MemoSection(memo: $memo)
                    }
                    .padding(12)
                }
                
                // 下部アクションバー
                ActionBar(
                    onUndo: undoLast,
                    onReset: { showResetAlert = true },
                    canUndo: !logs.isEmpty
                )
            }
            
            // フラッシュオーバーレイ
            if showFlash {
                flashColor.opacity(0.25)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .alert("リセット確認", isPresented: $showResetAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("リセット", role: .destructive) { resetAll() }
        } message: {
            Text("全てのカウントと総ゲーム数をリセットしますか？")
        }
        .sheet(isPresented: $showSpinInput) {
            SpinInputSheet(totalSpins: $totalSpins)
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    saveSession()
                    // ホーム画面まで戻る（NavigationPathをクリア）
                    navigationPath = NavigationPath()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("保存して戻る")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(AppColors.accent)
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("GAME")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(2)
            }
        }
        .toolbarBackground(AppColors.cardBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onChange(of: totalSpins) { _, _ in saveSession() }
        .onChange(of: items) { _, _ in saveSession() }
        .onChange(of: memo) { _, _ in saveSession() }
        .onAppear { loadExistingSession() }
    }
}

// MARK: - ステータスヘッダー
struct StatusHeaderView: View {
    let totalSpins: Int
    let bbTotal: Int
    let rbTotal: Int
    let combinedTotal: Int
    let startSpins: Int
    let startBB: Int
    let startRB: Int
    let onSpinTap: () -> Void
    
    private func rate(total: Int, spins: Int) -> String {
        let games = max(spins, 1)
        let per = Double(games) / Double(max(total, 1))
        return String(format: "1/%.0f", per)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 総ゲーム数（タップ可能）
                Button(action: onSpinTap) {
                    VStack(spacing: 2) {
                        HStack(spacing: 3) {
                            Text("GAMES")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(AppColors.grape)
                                .tracking(1)
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.grape.opacity(0.7))
                        }
                        
                        AnimatedNumberText(
                            value: "\(totalSpins)",
                            fontSize: 20,
                            color: AppColors.textPrimary
                        )
                        
                        // 常にstart値を表示
                        Text("start:\(startSpins)")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppColors.grape.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(AppColors.grape.opacity(0.1))
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .frame(height: 50)
                    .background(AppColors.divider)
                
                // 合算
                StatusCell(
                    label: "TOTAL",
                    value: rate(total: combinedTotal, spins: totalSpins),
                    subValue: nil,
                    startValue: nil,
                    color: AppColors.accent,
                    isLarge: true
                )
                
                Divider()
                    .frame(height: 50)
                    .background(AppColors.divider)
                
                // BB
                StatusCell(
                    label: "BB",
                    value: "\(bbTotal)",
                    subValue: nil,
                    startValue: startBB,
                    color: AppColors.bb,
                    isLarge: false
                )
                
                Divider()
                    .frame(height: 50)
                    .background(AppColors.divider)
                
                // RB
                StatusCell(
                    label: "RB",
                    value: "\(rbTotal)",
                    subValue: nil,
                    startValue: startRB,
                    color: AppColors.rb,
                    isLarge: false
                )
            }
            .background(AppColors.cardBackground)
        }
    }
}

struct StatusCell: View {
    let label: String
    let value: String
    let subValue: String?
    let startValue: Int?
    let color: Color
    let isLarge: Bool
    
    var body: some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
                .tracking(1)
            
            // アニメーション付き数字表示（全て20ptに統一）
            AnimatedNumberText(
                value: value,
                fontSize: 20,
                color: AppColors.textPrimary
            )
            
            if let sub = subValue {
                Text(sub)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppColors.textSecondary)
            }
            
            if let start = startValue {
                Text("start:\(start)")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(color.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

// MARK: - アニメーション付き数字表示
struct AnimatedNumberText: View {
    let value: String
    let fontSize: CGFloat
    let color: Color
    
    var body: some View {
        Text(value)
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .contentTransition(.numericText(countsDown: false))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
    }
}

// MARK: - ボーナスセクション
struct BonusSection: View {
    let title: String
    let color: Color
    let items: [CounterItem]
    let totalSpins: Int
    let effectiveSpins: Int  // 初期ゲーム数を引いた実効ゲーム数
    let increment: (CoinType) -> Void
    
    // 不明は全ゲーム数で計算、単独・重複は実効ゲーム数で計算
    private func rate(for item: CounterItem) -> String {
        let isUnknown = item.type == .bigUnknown || item.type == .regUnknown
        let spins = isUnknown ? totalSpins : effectiveSpins
        let games = max(spins, 1)
        let per = Double(games) / Double(max(item.count, 1))
        return String(format: "1/%.1f", per)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // セクションヘッダー
            HStack {
                Rectangle()
                    .fill(color)
                    .frame(width: 3, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                    .tracking(1)
                
                Spacer()
            }
            
            // カウンターグリッド
            HStack(spacing: 6) {
                ForEach(items, id: \.id) { item in
                    CounterCard(
                        item: item,
                        rate: rate(for: item),
                        onTap: { increment(item.type) }
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
        )
    }
}

struct CounterCard: View {
    let item: CounterItem
    let rate: String
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // ラベル（上部）
                Text(item.type.shortName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(item.type.color)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // カウント表示（アニメーション付き）
                Text("\(item.count)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: item.count)
                
                // 確率表示
                Text(rate)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppColors.textSecondary)
                
                // タップ促進インジケーター（指アイコンに統一）
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(item.type.color.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardBackgroundLight)
                    .shadow(color: item.type.color.opacity(0.2), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(item.type.color.opacity(0.4), lineWidth: 1.5)
            )
        }
        .buttonStyle(PressableButtonStyle(color: item.type.color))
    }
}

// MARK: - 押せる感のあるボタンスタイル
struct PressableButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 小役セクション（チェリー・ブドウ統合）
struct KoyakuSection: View {
    let items: [CounterItem]
    let totalSpins: Int
    let increment: (CoinType) -> Void
    
    private func rate(count: Int) -> String {
        let games = max(totalSpins, 1)
        let per = Double(games) / Double(max(count, 1))
        return String(format: "1/%.1f", per)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // セクションヘッダー
            HStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.cherry, AppColors.grape],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 3, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                
                Text("小役")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(1)
                
                Spacer()
            }
            
            // カウンターグリッド（横並び）
            HStack(spacing: 8) {
                ForEach(items, id: \.id) { item in
                    KoyakuCounterCard(
                        item: item,
                        rate: rate(count: item.count),
                        onTap: { increment(item.type) }
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
        )
    }
}

struct KoyakuCounterCard: View {
    let item: CounterItem
    let rate: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // アイコン/ラベル
                HStack(spacing: 4) {
                    Image(systemName: item.type == .cherry ? "leaf.fill" : "circle.grid.2x2.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(item.type.color)
                    Text(item.type.shortName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(item.type.color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(item.type.color.opacity(0.2))
                )
                
                // カウント表示（アニメーション付き）
                Text("\(item.count)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: item.count)
                
                // 確率表示
                Text(rate)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(item.type.color)
                
                // タップ促進
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.cardBackgroundLight)
                    .shadow(color: item.type.color.opacity(0.2), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(item.type.color.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(PressableButtonStyle(color: item.type.color))
    }
}

// MARK: - メモセクション
struct MemoSection: View {
    @Binding var memo: String
    
    var body: some View {
        VStack(spacing: 8) {
            // セクションヘッダー
            HStack {
                Rectangle()
                    .fill(AppColors.accent)
                    .frame(width: 3, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                
                Text("メモ")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(1)
                
                Spacer()
            }
            
            // メモ入力欄
            ZStack(alignment: .topLeading) {
                // プレースホルダー
                if memo.isEmpty {
                    Text("店舗名や台番号が記録できます")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                
                // テキストエディタ
                TextEditor(text: $memo)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
            .frame(minHeight: 60, maxHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.cardBackgroundLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
        )
    }
}

// MARK: - アクションバー
struct ActionBar: View {
    let onUndo: () -> Void
    let onReset: () -> Void
    let canUndo: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            // 戻るボタン
            Button(action: onUndo) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("1つ戻す")
                        .font(.system(size: 12, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(canUndo ? .white : AppColors.textSecondary)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canUndo ? Color.orange : AppColors.cardBackgroundLight)
                        .shadow(color: canUndo ? Color.orange.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(canUndo ? Color.orange.opacity(0.5) : AppColors.divider, lineWidth: 1.5)
                )
            }
            .disabled(!canUndo)
            .buttonStyle(PressableButtonStyle(color: .orange))

            // リセットボタン
            Button(action: onReset) {
                HStack(spacing: 6) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("リセット")
                        .font(.system(size: 12, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.bb)
                        .shadow(color: AppColors.bb.opacity(0.3), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.bb.opacity(0.5), lineWidth: 1.5)
                )
            }
            .buttonStyle(PressableButtonStyle(color: AppColors.bb))
        }
        .padding(12)
        .background(AppColors.cardBackground)
    }
}

// MARK: - ゲーム数入力シート
struct SpinInputSheet: View {
    @Binding var totalSpins: Int
    @Environment(\.dismiss) private var dismiss
    @State private var inputValue: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // ハンドル
            RoundedRectangle(cornerRadius: 3)
                .fill(AppColors.textSecondary)
                .frame(width: 36, height: 4)
                .padding(.top, 8)
            
            Text("総ゲーム数を入力")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
            
            TextField("0", text: $inputValue)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .foregroundStyle(AppColors.grape)
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.cardBackgroundLight)
                )
                .padding(.horizontal, 40)
            
            // クイック入力ボタン
            HStack(spacing: 10) {
                QuickAddButton(label: "+100", action: { addSpins(100) })
                QuickAddButton(label: "+500", action: { addSpins(500) })
                QuickAddButton(label: "+1000", action: { addSpins(1000) })
            }
            
            // 確定ボタン
            Button {
                if let value = Int(inputValue) {
                    totalSpins = value
                }
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("確定")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.accent)
                        .shadow(color: AppColors.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(PressableButtonStyle(color: AppColors.accent))
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .background(AppColors.background)
        .onAppear {
            inputValue = "\(totalSpins)"
        }
    }
    
    private func addSpins(_ amount: Int) {
        let current = Int(inputValue) ?? 0
        inputValue = "\(current + amount)"
    }
}

struct QuickAddButton: View {
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.accent.opacity(0.7))
                        .shadow(color: AppColors.accent.opacity(0.3), radius: 3, x: 0, y: 2)
                )
        }
        .buttonStyle(PressableButtonStyle(color: AppColors.accent))
    }
}

// MARK: - 設定判別画面
struct SettingJudgmentView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // アイコン
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(AppColors.accent)
                    }
                    
                    VStack(spacing: 8) {
                        Text("設定判別機能")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                        
                        Text("Coming Soon")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                            .tracking(2)
                    }
                }
            }
            .navigationTitle("設定判別")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - ブラウザ画面
struct BrowserView: View {
    @State private var urlString = ""
    @State private var currentURL = "https://www.google.com"
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // URLバー
                HStack(spacing: 12) {
                    // ナビゲーションボタン
                    HStack(spacing: 8) {
                        Button {
                            NotificationCenter.default.post(name: NSNotification.Name("webViewGoBack"), object: nil)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(canGoBack ? AppColors.accent : AppColors.textSecondary)
                                .frame(width: 36, height: 36)
                        }
                        .disabled(!canGoBack)
                        
                        Button {
                            NotificationCenter.default.post(name: NSNotification.Name("webViewGoForward"), object: nil)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(canGoForward ? AppColors.accent : AppColors.textSecondary)
                                .frame(width: 36, height: 36)
                        }
                        .disabled(!canGoForward)
                    }
                    
                    // URL入力フィールド
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.textSecondary)
                        
                        TextField("検索またはURL", text: $urlString)
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.textPrimary)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                            .submitLabel(.go)
                            .onSubmit { loadURL() }
                        
                        if !urlString.isEmpty {
                            Button {
                                urlString = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.cardBackgroundLight)
                    )
                    
                    // リロードボタン
                    Button {
                        NotificationCenter.default.post(name: NSNotification.Name("webViewReload"), object: nil)
                    } label: {
                        Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 36, height: 36)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppColors.cardBackground)
                
                // ローディングインジケーター
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(AppColors.accent)
                }
                
                // WebView
                WebView(
                    urlString: $currentURL,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    isLoading: $isLoading,
                    currentURLString: $urlString
                )
            }
            .navigationTitle("ブラウザ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            urlString = currentURL
        }
    }
    
    private func loadURL() {
        var urlToLoad = urlString.trimmingCharacters(in: .whitespaces)
        
        if !urlToLoad.hasPrefix("http://") && !urlToLoad.hasPrefix("https://") {
            if urlToLoad.contains(".") && !urlToLoad.contains(" ") {
                urlToLoad = "https://" + urlToLoad
            } else {
                let encoded = urlToLoad.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                urlToLoad = "https://www.google.com/search?q=\(encoded)"
            }
        }
        
        currentURL = urlToLoad
    }
}

// MARK: - WebView (WKWebView wrapper)
struct WebView: UIViewRepresentable {
    @Binding var urlString: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    @Binding var currentURLString: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        let dataStore = WKWebsiteDataStore.default()
        configuration.websiteDataStore = dataStore
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        let systemVersion = UIDevice.current.systemVersion
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS \(systemVersion.replacingOccurrences(of: ".", with: "_")) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1"
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.goBack),
            name: NSNotification.Name("webViewGoBack"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.goForward),
            name: NSNotification.Name("webViewGoForward"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.reload),
            name: NSNotification.Name("webViewReload"),
            object: nil
        )
        
        context.coordinator.webView = webView
        
        if let url = URL(string: urlString) {
            var request = URLRequest(url: url)
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: urlString) else { return }
        
        let currentURLString = webView.url?.absoluteString ?? ""
        let newURLString = url.absoluteString
        
        if currentURLString == newURLString { return }
        if webView.isLoading { return }
        if context.coordinator.lastLoadedURL == newURLString { return }
        
        context.coordinator.lastLoadedURL = newURLString
        
        var request = URLRequest(url: url)
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        webView.load(request)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        weak var webView: WKWebView?
        var lastLoadedURL: String = ""
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        @objc func goBack() { webView?.goBack() }
        @objc func goForward() { webView?.goForward() }
        @objc func reload() {
            if parent.isLoading { webView?.stopLoading() }
            else { webView?.reload() }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            
            if let url = webView.url?.absoluteString {
                DispatchQueue.main.async { [weak self] in
                    if self?.parent.currentURLString != url {
                        self?.parent.currentURLString = url
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// MARK: - カスタムボタンスタイル
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
