import SwiftUI

/// 主内容视图 - 管理学习流程和模式切换
///
/// 职责：
/// - 切换学习模式/复习模式/统计模式
/// - 导航控制（上一个/下一个）
/// - 重新学习功能
struct ContentView: View {
    @EnvironmentObject var sessionManager: LearningSessionManager
    @EnvironmentObject var settings: SettingsStore

    @State private var showStats: Bool = false
    @State private var showSettings: Bool = false
    @State private var showStatisticsInPlace: Bool = false
    @State private var isInSpellingMode: Bool = false
    @State private var isInDictationMode: Bool = false
    @State private var showMeanings: Bool = false
    @State private var showWordRootsDetail: Bool = false // ✅ 新增：显示词根/助记详情页面

    // MARK: - 页面切换动画状态
    @State private var currentPage: AppPage = .learning
    @State private var isPageTransitioning: Bool = false
    
    var currentWord: WordData? {
        guard !sessionManager.sessionWords.isEmpty else {
            return nil
        }
        
        let idx = sessionManager.sessionIndex
        if sessionManager.sessionWords.indices.contains(idx) {
            return sessionManager.sessionWords[idx]
        } else {
            if sessionManager.sessionWords.count > 0 {
                sessionManager.sessionIndex = 0
            }
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // 顶部工具栏 - 包含模式切换导航
            headerViewWithNavigation

            // 主内容区域 - 使用动画容器
            AnimatedPageContainer(currentPage: $currentPage) { page in
                mainContentView(for: page)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showStats) { StatsView().environmentObject(sessionManager) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear {
            if sessionManager.sessionWords.isEmpty {
                sessionManager.loadRandomSession(count: 20)
            }

            // ✅ 监听显示词根/助记详情的通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowWordRootsDetail"),
                object: nil,
                queue: .main
            ) { notification in
                if let word = notification.object as? WordData {
                    // 找到当前单词在数组中的位置
                    if let index = sessionManager.sessionWords.firstIndex(where: { $0.id == word.id }) {
                        sessionManager.sessionIndex = index
                    }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showWordRootsDetail = true
                    }
                }
            }

            // 同步页面状态
            syncPageState()
        }
        .onChange(of: isInSpellingMode) { _ in syncPageState() }
        .onChange(of: isInDictationMode) { _ in syncPageState() }
        .onChange(of: showStatisticsInPlace) { _ in syncPageState() }
        .frame(minWidth: 1024, minHeight: 768)
    }

    // MARK: - 页面状态同步

    private func syncPageState() {
        if showStatisticsInPlace {
            currentPage = .statistics
        } else if isInDictationMode {
            currentPage = .dictation
        } else if isInSpellingMode {
            currentPage = .spelling
        } else {
            currentPage = .learning
        }
    }

    private func handlePageChange(to page: AppPage) {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch page {
            case .learning:
                showStatisticsInPlace = false
                isInSpellingMode = false
                isInDictationMode = false
                showWordRootsDetail = false
            case .spelling:
                showStatisticsInPlace = false
                isInSpellingMode = true
                isInDictationMode = false
                showWordRootsDetail = false
            case .dictation:
                showStatisticsInPlace = false
                isInSpellingMode = false
                isInDictationMode = true
                showWordRootsDetail = false
            case .statistics:
                showStatisticsInPlace = true
                isInSpellingMode = false
                isInDictationMode = false
                showWordRootsDetail = false
            }
        }
    }

    // MARK: - 主内容视图

    @ViewBuilder
    private func mainContentView(for page: AppPage) -> some View {
        PageContentWrapper(page: page) {
            if sessionManager.sessionWords.isEmpty {
                emptyStateView
            } else if showWordRootsDetail, let word = currentWord {
            wordRootsDetailView(word: word)
        } else {
            switch page {
            case .learning:
                if let word = currentWord {
                    learningModeView(word: word)
                } else if sessionManager.isLoadingSession {
                    loadingStateView
                }
            case .spelling:
                spellingModeView
            case .dictation:
                dictationModeView
            case .statistics:
                statisticsView
            }
        }
        }
    }
    
    // MARK: - 子视图

    /// 顶部工具栏 - 包含模式切换导航
    private var headerViewWithNavigation: some View {
        HStack(spacing: 20) {
            // 左侧：App Logo/标题
            HStack(spacing: 8) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.2))
                Text("EasyEnglish")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
            }

            Spacer()

            // 中间：三个模式切换导航
            TopNavigationBar(currentPage: $currentPage) { page in
                handlePageChange(to: page)
            }

            Spacer()

            // 右侧：操作按钮
            HStack(spacing: 12) {
                if showStatisticsInPlace {
                    Button(action: { restartLearning() }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .semibold))
                            Text("再学一遍")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.65, blue: 0.25),
                                    Color(red: 0.95, green: 0.55, blue: 0.15)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(10)
                        .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(NSColor.windowBackgroundColor).opacity(0.9),
                    Color(NSColor.windowBackgroundColor)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// 原始headerView - 保留用于兼容
    private var headerView: some View {
        HStack {
            // 页面标题
            HStack(spacing: 8) {
                Image(systemName: currentPage.icon)
                    .foregroundColor(currentPage.color)
                Text(currentPage.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Spacer()

            if showStatisticsInPlace {
                Button("再学一遍") {
                    restartLearning()
                }
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .padding(.trailing, 12)
            }

            Button("设置") { showSettings = true }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    

    
    private var emptyStateView: some View {
        VStack {
            Text("未加载到学习单词")
                .foregroundColor(.secondary)
            Button("重新加载 20 个单词") { 
                sessionManager.loadRandomSession(count: 20) 
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var statisticsView: some View {
        StatsView(
            onRestartLearning: {
                self.restartLearning()
            }
        )
        .environmentObject(sessionManager)
    }
    
    private var spellingModeView: some View {
        ReviewSpellingView(
            learnedWords: sessionManager.sessionWords.filter { $0.isLearned },
            onShowStatistics: {
                // 拼写模式完成后跳转到听写模式
                withAnimation(.easeInOut(duration: 0.3)) {
                    isInSpellingMode = false
                    isInDictationMode = true
                }
            },
            isDictationMode: false
        )
        .environmentObject(sessionManager)
    }
    
    private var dictationModeView: some View {
        ReviewSpellingView(
            learnedWords: sessionManager.sessionWords.filter { $0.isLearned },
            onShowStatistics: {
                // 听写模式完成后跳转到统计页面
                self.showStatisticsInPlace = true
            },
            isDictationMode: true
        )
        .onAppear {
            // 发送听写模式开始的通知，确保输入焦点
            NotificationCenter.default.post(name: NSNotification.Name("DictationModeStarted"), object: nil)
        }
        .environmentObject(sessionManager)
    }
    
    // ✅ 新增：词根/助记详情视图
    private func wordRootsDetailView(word: WordData) -> some View {
        WordRootsDetailView(
            word: word,
            onBack: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showWordRootsDetail = false
                }
            }
        )
        .environmentObject(sessionManager)
    }
    
    private func learningModeView(word: WordData) -> some View {
        VStack(alignment: .center, spacing: 20) {
            // 单词卡片
            WordCardView(word: word, showMeanings: $showMeanings)
            
            // 控制按钮
            controlButtonsView(word: word)
            
            // 导航按钮
            navigationView
            
            // 搜索功能
            SearchView()
        }
        .padding(.horizontal, 80) // 左右各增加 80px 边距
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(NSColor.windowBackgroundColor).opacity(0.9),
                    Color(NSColor.windowBackgroundColor)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func controlButtonsView(word: WordData) -> some View {
        HStack(spacing: 16) {
            Button(action: { 
                sessionManager.review(word: word, quality: 4, attemptType: "manual") 
                next() 
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .medium)) // ✅ 调整图标大小为 14，与"上一个"一致
                    Text("认识")
                        .font(.system(size: 15, weight: .semibold)) // ✅ 调整文字大小为 15，与"上一个"一致
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24) // ✅ 水平内边距 24px，与"上一个"按钮一致
                .padding(.vertical, 10) // ✅ 调整垂直内边距为 10px，与"上一个"按钮一致
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.6, blue: 0.2), // 主橙色
                            Color(red: 0.95, green: 0.5, blue: 0.1) // 深橙色
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(10) // ✅ 调整圆角为 10，与"上一个"按钮一致
                .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.3), radius: 6, x: 0, y: 3) // ✅ 调整阴影与"上一个"一致
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { 
                showMeanings = true
                sessionManager.review(word: word, quality: 0, attemptType: "manual") 
            }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                    Text("不认识")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.6, blue: 0.2),
                            Color(red: 0.95, green: 0.5, blue: 0.1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(10) // ✅ 调整圆角为 10，与"上一个"按钮一致
                .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { 
                showMeanings = true
                sessionManager.review(word: word, quality: 0, attemptType: "manual") 
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                    Text("忘记")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.6, blue: 0.2),
                            Color(red: 0.95, green: 0.5, blue: 0.1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(10) // ✅ 调整圆角为 10，与"上一个"按钮一致
                .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }
    
    private var navigationView: some View {
        HStack(spacing: 16) {
            Button(action: prev) {
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("上一个")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.65, blue: 0.25),
                            Color(red: 0.95, green: 0.55, blue: 0.15)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(10)
                .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("\(sessionManager.sessionIndex + 1)/\(max(1, sessionManager.sessionWords.count))")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.9, blue: 0.8),
                            Color(red: 1.0, green: 0.85, blue: 0.75)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(10)
            
            // ✅ 当到达最后一个单词时，显示"进入拼写"按钮
            if isLastWord {
                Button(action: enterSpellingMode) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                        Text("进入拼写")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.65, blue: 0.25),
                                Color(red: 0.95, green: 0.55, blue: 0.15)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: next) {
                    HStack {
                        Text("下一个")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.65, blue: 0.25),
                                Color(red: 0.95, green: 0.55, blue: 0.15)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    /// ✅ 判断是否是最后一个单词
    private var isLastWord: Bool {
        guard !sessionManager.sessionWords.isEmpty else { return false }
        return sessionManager.sessionIndex == sessionManager.sessionWords.count - 1
    }
    
    /// ✅ 进入拼写模式
    private func enterSpellingMode() {
        Logger.info("🎯 进入拼写模式")
        isInSpellingMode = true
        showMeanings = false
    }
    
    private var loadingStateView: some View {
        VStack {
            ProgressView("正在加载单词...")
                .scaleEffect(1.5)
            Text("正在从数据库加载单词，请稍候")
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 方法
    
    private func next() {
        showMeanings = false
        
        let currentWord = sessionManager.sessionWords.count > 0 && sessionManager.sessionIndex < sessionManager.sessionWords.count 
            ? sessionManager.sessionWords[sessionManager.sessionIndex] 
            : nil
        
        if let word = currentWord, word.isLearned && sessionManager.sessionIndex == sessionManager.sessionWords.count - 1 {
            Logger.info("🎯 所有单词已学习完毕，自动进入拼写模式")
            isInSpellingMode = true
            return
        }
        
        if sessionManager.sessionIndex + 1 < sessionManager.sessionWords.count {
            sessionManager.sessionIndex += 1
        } else {
            sessionManager.sessionIndex = 0
        }
    }

    private func prev() {
        showMeanings = false
        
        if sessionManager.sessionIndex > 0 { 
            sessionManager.sessionIndex -= 1 
        }
    }
    
    private func restartLearning() {
        Logger.info("🔄 重新开始学习（复用当前单词）")

        var currentWords = sessionManager.sessionWords

        // 重置所有状态标志
        withAnimation(.easeInOut(duration: 0.3)) {
            isInSpellingMode = false
            isInDictationMode = false
            showStatisticsInPlace = false
            showStats = false
            currentPage = .learning
        }

        // 重置所有单词的学习状态
        for i in 0..<currentWords.count {
            var word = currentWords[i]
            word.isLearned = false
            word.learnedAt = nil
            word.masteryLevel = 0
            currentWords[i] = word
        }

        sessionManager.sessionWords = currentWords
        sessionManager.sessionIndex = 0

        Logger.success("✅ 已重置 \(currentWords.count) 个单词的学习状态，可以开始新的学习")
    }
}
