import SwiftUI

struct SearchView: View {
    @State private var searchQuery: String = ""
    @State private var searchResult: WordData? = nil
    @State private var isSearching: Bool = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 固定的搜索区域（距离顶部 8px）
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("输入英文单词", text: $searchQuery)
                    .font(.system(size: 14)) // 设置文字大小为 14
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isSearchFocused)
                    .onSubmit {
                        searchWord()
                    }
                    .onChange(of: searchQuery) { newValue in
                        if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            searchResult = nil
                        }
                    }
                
                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        searchResult = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button(action: searchWord) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white) // ✅ 改用白色背景，与英语例句一致
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            // 搜索结果区域（固定高度，可滚动）
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 20)
                    } else if let word = searchResult {
                        SearchResultCard(word: word)
                    } else if !searchQuery.isEmpty {
                        Text("未找到该单词")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 20)
                    }
                }
                .padding(.top, 12) // 搜索框与结果之间的间距
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isSearchFocused = true
            }
        }
    }
    
    private func searchWord() {
        guard !searchQuery.isEmpty else {
            searchResult = nil
            return
        }
        
        isSearching = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try WordDatabaseManager.shared.getWordDataBySearch(text: searchQuery)
                
                DispatchQueue.main.async {
                    self.isSearching = false
                    self.searchResult = result
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSearching = false
                    self.searchResult = nil
                }
                Logger.error("搜索失败：\(error)")
            }
        }
    }
}

// MARK: - 搜索结果卡片（只显示释义）
struct SearchResultCard: View {
    let word: WordData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 单词和发音按钮
            HStack {
                Text(word.text)
                    .font(.system(size: 20, weight: .bold))
                
                Spacer()
                
                Button(action: { TTSManager.shared.speak(word.text) }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 只显示释义（去掉音标、例句、词根等）
            if let meanings = word.meanings {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meanings)
                        .font(.system(size: 15))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    SearchView()
        .frame(width: 400, height: 500)
}
