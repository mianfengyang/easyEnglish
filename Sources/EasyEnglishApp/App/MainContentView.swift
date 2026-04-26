import SwiftUI

struct MainContentView: View {
    @StateObject private var learningVM: LearningViewModel
    @StateObject private var spellingVM: SpellingViewModel
    @StateObject private var statsVM: StatisticsViewModel
    @EnvironmentObject var settings: SettingsStore
    
    @State private var showStats: Bool = false
    @State private var showSettings: Bool = false
    @State private var showWordRootsDetail: Bool = false
    @State private var currentPage: AppPage = .learning
    @State private var selectedWordForRoots: Word = Word(id: UUID(), text: "", meanings: nil, examples: nil)
    
    private let repository: WordRepository
    
    init() {
        let repo = WordRepository()
        self.repository = repo
        _learningVM = StateObject(wrappedValue: LearningViewModel(repository: repo, settings: SettingsStore.shared))
        _spellingVM = StateObject(wrappedValue: SpellingViewModel(repository: repo))
        _statsVM = StateObject(wrappedValue: StatisticsViewModel(repository: repo))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            SideNavigationBar(currentPage: $currentPage, onPageChange: { page in
                handlePageChange(to: page)
            }, onSettingsTap: { showSettings = true })
            
            mainContentArea
        }
        .background(Theme.background)
        .overlay {
            if showWordRootsDetail {
                WordRootsDetailView(word: selectedWordForRoots, onBack: {
                    showWordRootsDetail = false
                })
            }
        }
        .sheet(isPresented: $showStats) {
            StatsView(viewModel: statsVM, onRestartLearning: restartLearning, onLearnMore: loadMoreWords)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            learningVM.loadInitialSession()
            setupNotifications()
        }
        .frame(minWidth: 1024, minHeight: 768)
    }
    
    @ViewBuilder
    private var mainContentArea: some View {
        AnimatedPageContainer(currentPage: $currentPage) { page in
            PageContentWrapper(page: page) {
                switch page {
                case .learning:
                    LearningView(viewModel: learningVM, onEnterSpellingMode: enterSpellingMode, onShowStatistics: enterStatistics)
                case .spelling, .dictation:
                    SpellingView(viewModel: spellingVM, isDictationMode: page == .dictation) {
                        if page == .spelling && !spellingVM.learnedWords.isEmpty {
                            spellingVM.currentIndex = 0
                            currentPage = .dictation
                        } else {
                            enterStatistics()
                        }
                    }
                    .id(page)
                case .statistics:
                    StatisticsView(viewModel: statsVM, onRestartLearning: restartLearning, onLearnMore: loadMoreWords)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func handlePageChange(to page: AppPage) {
        withAnimation(.easeInOut(duration: 0.25)) {
            switch page {
            case .learning:
                currentPage = .learning
            case .spelling:
                spellingVM.setWords(learningVM.sessionWords)
                spellingVM.currentIndex = 0
                currentPage = .spelling
            case .dictation:
                spellingVM.setWords(learningVM.sessionWords)
                spellingVM.currentIndex = 0
                currentPage = .dictation
            case .statistics:
                Task { await statsVM.loadStats() }
                currentPage = .statistics
            }
        }
    }
    
    private func enterSpellingMode() {
        spellingVM.setWords(learningVM.sessionWords)
        spellingVM.currentIndex = 0
        currentPage = .spelling
    }
    
    private func enterStatistics() {
        Task { await statsVM.loadStats() }
        currentPage = .statistics
    }
    
    private func restartLearning() {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentPage = .learning
            showStats = false
        }
        learningVM.resetSession()
        learningVM.sessionIndex = 0
    }
    
    private func loadMoreWords(count: Int) {
        let loadCount = settings.dailyNewLimit
        Task {
            await learningVM.loadMoreWords(count: loadCount)
            withAnimation(.easeInOut(duration: 0.25)) {
                currentPage = .learning
                showStats = false
            }
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowWordRootsDetail"), object: nil, queue: .main) { notification in
            Task { @MainActor in
                if let word = notification.object as? Word {
                    selectedWordForRoots = word
                    if let index = learningVM.sessionWords.firstIndex(where: { $0.id == word.id }) {
                        learningVM.sessionIndex = index
                    }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showWordRootsDetail = true
                    }
                }
            }
        }
    }
}