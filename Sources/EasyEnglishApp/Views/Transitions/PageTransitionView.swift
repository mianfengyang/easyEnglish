import SwiftUI

/// 页面类型枚举 - 用于标识四个主要功能页面
enum AppPage: Int, CaseIterable, Identifiable {
    case learning = 0
    case spelling = 1
    case dictation = 2
    case statistics = 3
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .learning: return "学习"
        case .spelling: return "拼写"
        case .dictation: return "听写"
        case .statistics: return "统计"
        }
    }
    
    var icon: String {
        switch self {
        case .learning: return "book.fill"
        case .spelling: return "pencil.and.outline"
        case .dictation: return "mic.fill"
        case .statistics: return "chart.bar.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .learning: return .blue
        case .spelling: return .orange
        case .dictation: return .purple
        case .statistics: return .green
        }
    }
}

/// 页面转场方向
enum TransitionDirection {
    case leftToRight
    case rightToLeft
    case bottomToTop
    case topToBottom
    case scale
    case fade
}

/// 页面转场动画修饰器
struct PageTransitionModifier: ViewModifier {
    let direction: TransitionDirection
    let isActive: Bool
    let animation: Animation
    
    func body(content: Content) -> some View {
        content
            .offset(offsetValue)
            .scaleEffect(scaleValue)
            .opacity(opacityValue)
            .animation(animation, value: isActive)
    }
    
    private var offsetValue: CGSize {
        guard isActive else { return .zero }
        switch direction {
        case .leftToRight:
            return CGSize(width: -100, height: 0)
        case .rightToLeft:
            return CGSize(width: 100, height: 0)
        case .bottomToTop:
            return CGSize(width: 0, height: 100)
        case .topToBottom:
            return CGSize(width: 0, height: -100)
        case .scale, .fade:
            return .zero
        }
    }
    
    private var scaleValue: CGFloat {
        guard isActive else { return 1.0 }
        switch direction {
        case .scale:
            return 0.85
        case .leftToRight, .rightToLeft, .bottomToTop, .topToBottom, .fade:
            return 1.0
        }
    }
    
    private var opacityValue: CGFloat {
        isActive ? 0 : 1
    }
}

/// 页面切换动画视图容器
/// 管理三个主要页面之间的切换动画
struct AnimatedPageContainer<Content: View>: View {
    @Binding var currentPage: AppPage
    let content: (AppPage) -> Content
    
    @State private var previousPage: AppPage = .learning
    @State private var isTransitioning: Bool = false
    @State private var transitionDirection: TransitionDirection = .rightToLeft
    
    // 动画配置
    private let transitionDuration: Double = 0.4
    private let springResponse: Double = 0.5
    private let springDamping: Double = 0.8
    
    var body: some View {
        ZStack {
            // 当前页面
            content(currentPage)
                .id(currentPage.id)
                .modifier(PageTransitionModifier(
                    direction: transitionDirection,
                    isActive: isTransitioning,
                    animation: transitionAnimation
                ))
                .zIndex(1)
        }
        .onChange(of: currentPage) { newPage in
            handlePageChange(from: previousPage, to: newPage)
        }
    }
    
    private var transitionAnimation: Animation {
        .spring(response: springResponse, dampingFraction: springDamping)
    }
    
    private func handlePageChange(from oldPage: AppPage, to newPage: AppPage) {
        // 确定转场方向
        transitionDirection = determineDirection(from: oldPage, to: newPage)
        
        // 开始转场动画
        withAnimation(transitionAnimation) {
            isTransitioning = true
        }
        
        // 动画完成后更新状态
        DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration * 0.3) {
            previousPage = newPage
            
            withAnimation(transitionAnimation) {
                isTransitioning = false
            }
        }
    }
    
    private func determineDirection(from oldPage: AppPage, to newPage: AppPage) -> TransitionDirection {
        let diff = newPage.rawValue - oldPage.rawValue
        if diff > 0 {
            return .rightToLeft
        } else if diff < 0 {
            return .leftToRight
        } else {
            return .fade
        }
    }
}

/// 顶部导航栏 - 带切换动画指示器
struct TopNavigationBar: View {
    @Binding var currentPage: AppPage
    let onPageSelected: ((AppPage) -> Void)?

    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppPage.allCases) { page in
                TopNavigationButton(
                    page: page,
                    isSelected: currentPage == page,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        currentPage = page
                        onPageSelected?(page)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }
}

/// 顶部导航按钮 - 水平布局
private struct TopNavigationButton: View {
    let page: AppPage
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: page.icon)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? page.color : .gray)

                Text(page.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? page.color : .gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(page.color.opacity(0.12))
                            .matchedGeometryEffect(id: "indicator_\(page.id)", in: namespace)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 保留旧名称的别名，以便兼容现有代码
@available(*, deprecated, renamed: "TopNavigationBar")
typealias BottomNavigationBar = TopNavigationBar



/// 页面内容包装器 - 添加进入/退出动画
struct PageContentWrapper<Content: View>: View {
    let page: AppPage
    @ViewBuilder let content: Content
    
    @State private var appearAnimation: Bool = false
    
    var body: some View {
        content
            .opacity(appearAnimation ? 1 : 0)
            .offset(y: appearAnimation ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
                    appearAnimation = true
                }
            }
            .onDisappear {
                appearAnimation = false
            }
    }
}

// MARK: - 预览
#Preview {
    struct PreviewContainer: View {
        @State private var currentPage: AppPage = .learning
        
        var body: some View {
            VStack {
                AnimatedPageContainer(currentPage: $currentPage) { page in
                    switch page {
                    case .learning:
                        PageContentWrapper(page: page) {
                            VStack {
                                Text("学习页面")
                                    .font(.largeTitle)
                                    .foregroundColor(.blue)
                                Text("单词卡片学习")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    case .spelling:
                        PageContentWrapper(page: page) {
                            VStack {
                                Text("拼写模式")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text("拼写测试练习")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    case .dictation:
                        PageContentWrapper(page: page) {
                            VStack {
                                Text("听写模式")
                                    .font(.largeTitle)
                                    .foregroundColor(.purple)
                                Text("听写测试练习")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    case .statistics:
                        PageContentWrapper(page: page) {
                            VStack {
                                Text("学习统计")
                                    .font(.largeTitle)
                                    .foregroundColor(.green)
                                Text("学习数据统计")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                
                TopNavigationBar(currentPage: $currentPage, onPageSelected: nil)
            }
            .frame(width: 800, height: 600)
        }
    }
    
    return PreviewContainer()
}
