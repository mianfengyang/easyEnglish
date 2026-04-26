import SwiftUI

struct WordRootsDetailView: View {
    let word: Word
    var onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
                .padding(.horizontal, 40)
            rootsContentSection
            Spacer()
            footerSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text(word.text)
                .font(.system(size: 48, weight: .bold))
                .textSelection(.enabled)
            
            if let ipa = word.ipa {
                Text(ipa)
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))
            }
        }
        .padding(.vertical, 32)
    }
    
    private var rootsContentSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.2))
                    Text("词根 / 助记")
                        .font(.system(size: 20, weight: .semibold))
                }
                
                if let roots = word.roots, !roots.isEmpty {
                    Text(roots)
                        .font(.system(size: 16))
                        .lineSpacing(6)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("暂无词根/助记信息")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
        }
    }
    
    private var footerSection: some View {
        HStack {
            SecondaryButton("返回学习", icon: "chevron.left") {
                onBack()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.vertical, 24)
    }
}