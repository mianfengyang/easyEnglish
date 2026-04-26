import SwiftUI

struct TopNavigationBar: View {
    @Binding var currentPage: AppPage
    var onPageChange: (AppPage) -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppPage.allCases, id: \.self) { page in
                NavTabButton(
                    page: page,
                    isActive: currentPage == page,
                    onTap: { onPageChange(page) }
                )
            }
        }
        .padding(6)
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
    }
}

struct NavTabButton: View {
    let page: AppPage
    let isActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: page.icon)
                    .font(.system(size: 15))
                Text(page.title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isActive ? .white : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isActive ? Theme.primary.opacity(0.8) : Color.clear)
            .cornerRadius(8)
            .scaleEffect(isActive ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

struct AnimatedPageContainer<Content: View>: View {
    @Binding var currentPage: AppPage
    @ViewBuilder var content: (AppPage) -> Content
    
    var body: some View {
        content(currentPage)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.25), value: currentPage)
    }
}

struct PageContentWrapper<Content: View>: View {
    let page: AppPage
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        content()
    }
}

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        AccentButton(title, icon: icon, action: action)
    }
}

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        SecondaryActionButton(title, icon: icon, action: action)
    }
}

struct ProgressIndicator: View {
    let current: Int
    let total: Int
    
    var body: some View {
        ProgressBadge(current: current, total: total)
    }
}

struct IconButton: View {
    let icon: String
    let action: () -> Void
    var color: Color = Theme.primary
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .padding(8)
                .background(Theme.tertiaryBackground)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 26, weight: .bold))
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Theme.secondaryBackground.opacity(0.5))
        .cornerRadius(12)
    }
}

struct MasteryBar: View {
    let level: Int
    let count: Int64
    let total: Int
    
    var body: some View {
        VStack(spacing: 6) {
            Text("L\(level)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            RoundedRectangle(cornerRadius: 4)
                .fill(masteryColor)
                .frame(width: 32, height: max(12, CGFloat(count) / max(1, CGFloat(total)) * 80))
            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    private var masteryColor: Color {
        switch level {
        case 0: return Color.gray.opacity(0.4)
        case 1: return Theme.danger
        case 2: return Theme.warning
        case 3: return Color.yellow
        case 4: return Theme.success.opacity(0.7)
        case 5: return Theme.success
        default: return Color.gray.opacity(0.4)
        }
    }
}

struct WordBadge: View {
    let word: Word
    
    var body: some View {
        Text(word.text)
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.secondaryBackground)
            .cornerRadius(6)
    }
}