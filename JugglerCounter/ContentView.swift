import SwiftUI
import WebKit

// 子役の種類を定義
enum CoinType: String, CaseIterable, Identifiable {
    case bigSingle = "BIG単独"
    case bigOverlap = "BIG重複"
    case regSingle = "REG単独"
    case regOverlap = "REG重複"
    case cherrySingle = "チェリー単独"
    case cherryOverlap = "チェリー重複"
    case grape = "ブドウ"
    case bell = "ベル"
    case replay = "リプレイ"

    var id: String { rawValue }

    // 各子役の表示色
    var color: Color {
        switch self {
        case .bigSingle, .bigOverlap: return .red
        case .regSingle, .regOverlap: return .orange
        case .cherrySingle, .cherryOverlap: return .purple
        case .grape: return .green
        case .bell: return .yellow
        case .replay: return .blue
        }
    }
    
    // カウント項目に表示するイラスト名（SF Symbolsまたはアセット名）
    var iconName: String? {
        switch self {
        case .bigSingle, .bigOverlap: return "bb_icon" // ★ここにBBのイラスト名を指定（例: "bb_icon"）
        case .regSingle, .regOverlap: return "rb_icon" // ★ここにRBのイラスト名を指定（例: "rb_icon"）
        default: return nil
        }
    }
}

// カウント項目のデータ構造
struct CounterItem: Identifiable, Hashable {
    let id = UUID()
    let type: CoinType
    var count: Int = 0
}

// UNDO用の履歴データ
struct ActionLog: Identifiable {
    let id = UUID()
    let type: CoinType
    let timestamp: Date
}

// ゲーム履歴データ（保存用）
struct GameSession: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    var endDate: Date
    var totalSpins: Int
    var counters: [String: Int] // CoinType.rawValue: count
    
    init(id: UUID = UUID(), startDate: Date = Date(), endDate: Date = Date(), totalSpins: Int = 0, counters: [String: Int] = [:]) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.totalSpins = totalSpins
        self.counters = counters
    }
    
    // BB合計を計算
    var bbTotal: Int {
        (counters[CoinType.bigSingle.rawValue] ?? 0) + (counters[CoinType.bigOverlap.rawValue] ?? 0)
    }
    
    // RB合計を計算
    var rbTotal: Int {
        (counters[CoinType.regSingle.rawValue] ?? 0) + (counters[CoinType.regOverlap.rawValue] ?? 0)
    }
    
    // 合算確率
    var combinedRate: String {
        let total = bbTotal + rbTotal
        let games = max(totalSpins, 1)
        let rate = Double(games) / Double(max(total, 1))
        return String(format: "1/%.0f", rate)
    }
}

// メインビュー（タブバー管理）
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var gameSessions: [GameSession] = []
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // ホームタブ（ゲーム履歴画面）
            GameHistoryView(gameSessions: $gameSessions)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("ホーム")
                }
                .tag(0)
            
            // 設定判別タブ
            SettingJudgmentView()
                .tabItem {
                    Image(systemName: "chart.xyaxis.line")
                    Text("設定判別")
                }
                .tag(1)
            
            // ブラウザタブ
            BrowserView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("ブラウザ")
                }
                .tag(2)
        }
        .preferredColorScheme(.dark) // ダークモード強制
    }
}

// ゲーム履歴画面（新規ゲームボタン + 履歴リスト）
struct GameHistoryView: View {
    @Binding var gameSessions: [GameSession]
    @State private var isNewGamePressed = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.11, blue: 0.12)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // 新規ゲームボタン
                    NavigationLink {
                        CounterView(gameSessions: $gameSessions)
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("新規ゲーム")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        .scaleEffect(isNewGamePressed ? 0.95 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: isNewGamePressed)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // 履歴リスト
                    if gameSessions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            Text("履歴がありません")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text("「新規ゲーム」ボタンでゲームを開始してください")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(gameSessions.sorted(by: { $0.endDate > $1.endDate }), id: \.id) { session in
                                    // すべての履歴をタップ可能に変更
                                    NavigationLink {
                                        CounterView(gameSessions: $gameSessions, existingSession: session)
                                    } label: {
                                        GameSessionRow(session: session, isLocked: false)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
            .navigationTitle("ジャグラーカウンター")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.11, green: 0.11, blue: 0.12), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// ゲームセッション行ビュー
struct GameSessionRow: View {
    let session: GameSession
    let isLocked: Bool // 今後の拡張用に残しておくが、現在は未使用
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 1行目：日付、ゲーム数、合算確率
            HStack {
                Text(session.startDate, style: .date)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(session.totalSpins)G")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
                
                Spacer()
                
                Text(session.combinedRate)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.cyan)
            }
            
            // 2行目：時刻と矢印
            HStack {
                Text(session.startDate, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

// ゲーム詳細画面（過去の履歴を表示）
struct GameDetailView: View {
    let session: GameSession
    
    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.12)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // サマリー情報
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("開始時刻")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(session.startDate, style: .time)
                                    .font(.body)
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("終了時刻")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(session.endDate, style: .time)
                                    .font(.body)
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("総ゲーム数")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(session.totalSpins)G")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("合算確率")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(session.combinedRate)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.cyan)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // カウント詳細
                    VStack(alignment: .leading, spacing: 12) {
                        Text("カウント詳細")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(CoinType.allCases) { type in
                                let count = session.counters[type.rawValue] ?? 0
                                VStack(spacing: 8) {
                                    HStack {
                                        if let iconName = type.iconName {
                                            Image(iconName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 16, height: 16)
                                        }
                                        Text(type.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(type.color)
                                        Spacer()
                                    }
                                    
                                    Text("\(count)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(.thinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("ゲーム詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.11, green: 0.11, blue: 0.12), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

// カウンター画面（旧HomeView）
struct CounterView: View {
    @Binding var gameSessions: [GameSession]
    @Environment(\.dismiss) private var dismiss
    
    // 既存のセッションを読み込む場合に使用
    var existingSession: GameSession?
    
    // カウンター項目の配列
    @State private var items: [CounterItem] = []
    // 総ゲーム数
    @State private var totalSpins: Int = 0
    // 操作履歴
    @State private var logs: [ActionLog] = []
    // セッションID
    @State private var sessionId = UUID()
    @State private var sessionStartDate = Date()
    
    init(gameSessions: Binding<[GameSession]>, existingSession: GameSession? = nil) {
        self._gameSessions = gameSessions
        self.existingSession = existingSession
    }
    
    // 画面を閉じる時にセッションを保存
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
            counters: counters
        )
        
        // 既存のセッションを更新または追加
        if let index = gameSessions.firstIndex(where: { $0.id == sessionId }) {
            gameSessions[index] = session
        } else {
            gameSessions.append(session)
        }
    }

    // カウントを1増やす
    private func increment(_ type: CoinType) {
        if let idx = items.firstIndex(where: { $0.type == type }) {
            items[idx].count += 1
            logs.append(ActionLog(type: type, timestamp: Date()))
        }
    }

    // カウントを1減らす
    private func decrement(_ type: CoinType) {
        if let idx = items.firstIndex(where: { $0.type == type }), items[idx].count > 0 {
            items[idx].count -= 1
        }
    }

    // 最後の操作を取り消す
    private func undoLast() {
        guard let last = logs.popLast(), let idx = items.firstIndex(where: { $0.type == last.type }) else { return }
        if items[idx].count > 0 { items[idx].count -= 1 }
    }

    // 全てのカウントをリセット
    private func resetAll() {
        for i in items.indices { items[i].count = 0 }
        totalSpins = 0
        logs.removeAll()
    }
    
    // 既存セッションのデータを読み込む
    private func loadExistingSession() {
        if let session = existingSession {
            // セッション情報を復元
            sessionId = session.id
            sessionStartDate = session.startDate
            totalSpins = session.totalSpins
            
            // カウンターデータを復元
            items = CoinType.allCases.map { type in
                let count = session.counters[type.rawValue] ?? 0
                return CounterItem(type: type, count: count)
            }
        } else {
            // 新規セッション
            items = CoinType.allCases.map { CounterItem(type: $0, count: 0) }
        }
    }

    // デジタル表示スタイルを適用するModifier（アンダーライン版）
    private func digitalNumberStyle(color: Color, backgroundGhost: String? = nil, fixedWidth: CGFloat? = nil) -> some ViewModifier {
        struct DigitalStyle: ViewModifier {
            let color: Color
            let backgroundGhost: String?
            let fixedWidth: CGFloat?
            func body(content: Content) -> some View {
                VStack(spacing: 2) {
                    ZStack(alignment: .trailing) {
                        // 背景のゴースト数字（薄く表示）
                        if let ghost = backgroundGhost {
                            Text(ghost)
                                .font(.system(size: 20, weight: .medium, design: .monospaced))
                                .monospacedDigit()
                                .kerning(-0.5)
                                .foregroundStyle(Color.white.opacity(0.08))
                                .lineLimit(1)
                        }
                        
                        // 前景の数字（右寄せで発光効果付き）
                        content
                            .font(.system(size: 20, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .kerning(-0.5)
                            .lineLimit(1)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [color, color.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: color.opacity(0.6), radius: 3, x: 0, y: 0)
                    }
                    .frame(width: fixedWidth, alignment: .trailing)
                    
                    // アンダーライン
                    Rectangle()
                        .fill(color)
                        .frame(width: fixedWidth, height: 2)
                }
            }
        }
        return DigitalStyle(color: color, backgroundGhost: backgroundGhost, fixedWidth: fixedWidth)
    }

    // 各子役の出現率を計算（1/x形式）
    private func rate(for type: CoinType) -> String {
        let games = max(totalSpins, 1)
        let count = items.first(where: { $0.type == type })?.count ?? 0
        let per = Double(games) / Double(max(count, 1))
        return String(format: "1/%.1f", per)
    }

    var body: some View {
        ZStack {
            // 背景色をマイルドなダークグレーに設定
            Color(red: 0.11, green: 0.11, blue: 0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 10) {
                // 上部ステータス表示エリア
                VStack(spacing: 4) {
                    HStack(alignment: .top, spacing: 4) {
                        // 総ゲーム数表示
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("総ゲーム数")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text(String(format: "%d", totalSpins))
                                .modifier(digitalNumberStyle(color: .green, backgroundGhost: "88888", fixedWidth: 80))
                        }
                        .frame(maxWidth: .infinity)
                        
                        // 合算確率表示（BB+RB）
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("合算")
                                .font(.caption)
                                .foregroundStyle(.cyan)
                            // BB合計を計算
                            let bigTotal = (items.first(where: { $0.type == .bigSingle })?.count ?? 0) + (items.first(where: { $0.type == .bigOverlap })?.count ?? 0)
                            // RB合計を計算
                            let regTotal = (items.first(where: { $0.type == .regSingle })?.count ?? 0) + (items.first(where: { $0.type == .regOverlap })?.count ?? 0)
                            // BB+RBの合計
                            let total = bigTotal + regTotal
                            let games = max(totalSpins, 1)
                            let combined = Double(games) / Double(max(total, 1))
                            Text(String(format: "1/%.0f", combined))
                                .modifier(digitalNumberStyle(color: .cyan, backgroundGhost: "1/888", fixedWidth: 80))
                        }
                        .frame(maxWidth: .infinity)
                        
                        // BB合計表示
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("BB")
                                .font(.caption)
                                .foregroundStyle(.red)
                            // BB単独+BB重複を合計
                            let bigTotal = (items.first(where: { $0.type == .bigSingle })?.count ?? 0) + (items.first(where: { $0.type == .bigOverlap })?.count ?? 0)
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%d", bigTotal))
                                    .modifier(digitalNumberStyle(color: .red, backgroundGhost: "88888", fixedWidth: 80))
                                // BB確率を計算
                                let games = max(totalSpins, 1)
                                let per = Double(games) / Double(max(bigTotal, 1))
                                Text(String(format: "1/%.1f", per))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // RB合計表示
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("RB")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            // RB単独+RB重複を合計
                            let regTotal = (items.first(where: { $0.type == .regSingle })?.count ?? 0) + (items.first(where: { $0.type == .regOverlap })?.count ?? 0)
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%d", regTotal))
                                    .modifier(digitalNumberStyle(color: .orange, backgroundGhost: "88888", fixedWidth: 80))
                                // RB確率を計算
                                let games = max(totalSpins, 1)
                                let per = Double(games) / Double(max(regTotal, 1))
                                Text(String(format: "1/%.1f", per))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // 総ゲーム数入力エリア
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("総ゲーム数")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                // 数値入力フィールド
                                TextField("入力", value: $totalSpins, format: .number)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                // 増減ボタン
                                Stepper("", value: $totalSpins, in: 0...99999)
                                    .labelsHidden()
                                    .frame(width: 80)
                            }
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 2)

                // 子役カウント項目グリッド（3列）
                LazyVGrid(columns: [
                    GridItem(.flexible(minimum: 100, maximum: .infinity), spacing: 6),
                    GridItem(.flexible(minimum: 100, maximum: .infinity), spacing: 6),
                    GridItem(.flexible(minimum: 100, maximum: .infinity), spacing: 6)
                ], spacing: 6) {
                    ForEach(items.indices, id: \.self) { idx in
                        let item = items[idx]
                        VStack(spacing: 4) {
                            // 子役名と出現率
                            HStack {
                                // ★イラスト表示（アイコンがある場合）
                                if let iconName = item.type.iconName {
                                    Image(iconName) // アセットに追加したイラスト名
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                }
                                Text(item.type.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(item.type.color)
                                Spacer()
                                Text(rate(for: item.type))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            // カウント数表示
                            Text("\(item.count)")
                                .font(.system(size: 22, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            // カウントボタン
                            HStack(spacing: 6) {
                                // マイナスボタン
                                Button {
                                    decrement(item.type)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)

                                // プラスボタン
                                Button {
                                    increment(item.type)
                                } label: {
                                    HStack(spacing: 2) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.caption)
                                        Text("カウント")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .foregroundStyle(.white)
                                    .background(item.type.color)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(6)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 2)
                .padding(.bottom, 2)

                // 下部操作ボタンエリア
                HStack(spacing: 12) {
                    // 戻るボタン
                    Button {
                        undoLast()
                    } label: {
                        Label("Back", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // リセットボタン
                    Button(role: .destructive) {
                        resetAll()
                    } label: {
                        Label("RESET", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("ゲーム中")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.11, green: 0.11, blue: 0.12), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    saveSession()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body)
                        Text("保存して戻る")
                            .font(.body)
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .onChange(of: totalSpins) { _, _ in
            saveSession()
        }
        .onChange(of: items) { _, _ in
            saveSession()
        }
        .onAppear {
            loadExistingSession()
        }
    }
}

// カスタムボタンスタイル（タップ時のスケールアニメーション）
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// 設定判別画面
struct SettingJudgmentView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.11, blue: 0.12)
                    .ignoresSafeArea()
                
                VStack {
                    Text("設定判別機能")
                        .font(.title)
                        .foregroundStyle(.white)
                    Text("準備中")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定判別")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.11, green: 0.11, blue: 0.12), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// ブラウザ画面
struct BrowserView: View {
    @State private var urlString = ""
    @State private var currentURL = "https://www.google.com"
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // URLバー＆コントロール
                VStack(spacing: 8) {
                    // ナビゲーションボタン
                    HStack(spacing: 12) {
                        // 戻るボタン
                        Button {
                            NotificationCenter.default.post(name: NSNotification.Name("webViewGoBack"), object: nil)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundStyle(canGoBack ? .blue : .gray)
                                .frame(width: 44, height: 44)
                        }
                        .disabled(!canGoBack)
                        
                        // 進むボタン
                        Button {
                            NotificationCenter.default.post(name: NSNotification.Name("webViewGoForward"), object: nil)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title3)
                                .foregroundStyle(canGoForward ? .blue : .gray)
                                .frame(width: 44, height: 44)
                        }
                        .disabled(!canGoForward)
                        
                        // 更新ボタン
                        Button {
                            NotificationCenter.default.post(name: NSNotification.Name("webViewReload"), object: nil)
                        } label: {
                            Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 44, height: 44)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // URL入力バー
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("検索またはURLを入力", text: $urlString, onCommit: {
                            loadURL()
                        })
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .submitLabel(.go)
                        
                        if !urlString.isEmpty {
                            Button {
                                urlString = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                
                // ローディングインジケーター
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.linear)
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
            .toolbarBackground(Color(red: 0.11, green: 0.11, blue: 0.12), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            urlString = currentURL
        }
    }
    
    private func loadURL() {
        var urlToLoad = urlString.trimmingCharacters(in: .whitespaces)
        
        // URLかどうかを判定
        if !urlToLoad.hasPrefix("http://") && !urlToLoad.hasPrefix("https://") {
            // URLでない場合はGoogle検索
            if urlToLoad.contains(".") && !urlToLoad.contains(" ") {
                // ドメインっぽい場合はhttpsを追加
                urlToLoad = "https://" + urlToLoad
            } else {
                // それ以外はGoogle検索
                let encoded = urlToLoad.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                urlToLoad = "https://www.google.com/search?q=\(encoded)"
            }
        }
        
        currentURL = urlToLoad
    }
}

// WKWebViewのSwiftUIラッパー
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
        // WebView設定
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // JavaScriptを有効化
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        // データストアを設定（Cookie、LocalStorageを有効化）
        let dataStore = WKWebsiteDataStore.default()
        configuration.websiteDataStore = dataStore
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // より詳細なUser-Agentを設定
        let systemVersion = UIDevice.current.systemVersion
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS \(systemVersion.replacingOccurrences(of: ".", with: "_")) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1"
        
        // 通知の監視
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
            // より詳細なリクエストヘッダーを設定
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
            request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
            request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
            request.setValue("?1", forHTTPHeaderField: "Sec-Fetch-User")
            request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // 現在のURLと新しいURLを正規化して比較
        guard let url = URL(string: urlString) else { return }
        
        let currentURLString = webView.url?.absoluteString ?? ""
        let newURLString = url.absoluteString
        
        // URLが完全に一致する場合は何もしない
        if currentURLString == newURLString {
            return
        }
        
        // ロード中の場合は何もしない
        if webView.isLoading {
            return
        }
        
        // 最後にロードしたURLを記憶して、重複ロードを防ぐ
        if context.coordinator.lastLoadedURL == newURLString {
            return
        }
        
        context.coordinator.lastLoadedURL = newURLString
        
        var request = URLRequest(url: url)
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("?1", forHTTPHeaderField: "Sec-Fetch-User")
        request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        webView.load(request)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        weak var webView: WKWebView?
        var lastLoadedURL: String = ""
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        @objc func goBack() {
            webView?.goBack()
        }
        
        @objc func goForward() {
            webView?.goForward()
        }
        
        @objc func reload() {
            if parent.isLoading {
                webView?.stopLoading()
            } else {
                webView?.reload()
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            
            if let url = webView.url?.absoluteString {
                // 無限ループを防ぐため、URLが変わった時だけ更新
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

#Preview {
    ContentView()
}
