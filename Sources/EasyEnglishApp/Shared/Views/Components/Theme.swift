import SwiftUI

struct Theme {
    static let primary = Color(red: 0.98, green: 0.58, blue: 0.15)
    static let primaryDark = Color(red: 0.95, green: 0.48, blue: 0.08)
    static let secondary = Color(red: 1.0, green: 0.68, blue: 0.26)
    static let secondaryDark = Color(red: 0.95, green: 0.55, blue: 0.15)
    
    static let background = Color(NSColor.windowBackgroundColor)
    static let secondaryBackground = Color(NSColor.controlBackgroundColor)
    static let tertiaryBackground = Color(NSColor.controlBackgroundColor).opacity(0.6)
    
    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red
}

struct AccentButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(Theme.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Theme.primary.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SecondaryActionButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(Theme.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Theme.primary.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GhostButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(Theme.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Theme.primary.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProgressBadge: View {
    let current: Int
    let total: Int
    
    var body: some View {
        Text("\(current)/\(max(1, total))")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.secondaryBackground)
            .cornerRadius(8)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Theme.secondaryBackground.opacity(0.5))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}