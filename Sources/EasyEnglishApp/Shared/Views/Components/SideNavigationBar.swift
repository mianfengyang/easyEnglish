import SwiftUI

struct SideNavigationBar: View {
    @Binding var currentPage: AppPage
    var onPageChange: (AppPage) -> Void
    var onSettingsTap: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            logoSection
            Divider()
                .padding(.vertical, 12)
            navSection
            Spacer()
            settingsSection
        }
        .padding(.vertical, 16)
        .frame(width: 72)
        .background(Theme.secondaryBackground)
    }
    
    private var logoSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.primary)
            }
            Text("EasyEnglish")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
    
    private var navSection: some View {
        VStack(spacing: 12) {
            ForEach(AppPage.allCases, id: \.self) { page in
                SideNavButton(
                    page: page,
                    isActive: currentPage == page,
                    onTap: { onPageChange(page) }
                )
            }
        }
    }
    
    private var settingsSection: some View {
        IconButton(icon: "gearshape.fill", action: {
            onSettingsTap?()
        })
    }
}

struct SideNavButton: View {
    let page: AppPage
    let isActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    if isActive {
                        Circle()
                            .fill(Theme.primary.opacity(0.15))
                            .frame(width: 44, height: 44)
                    }
                    Image(systemName: page.icon)
                        .font(.system(size: 18))
                }
                Text(page.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isActive ? Theme.primary : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 72)
    }
}