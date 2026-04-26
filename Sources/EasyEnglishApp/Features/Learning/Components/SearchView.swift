import SwiftUI

struct SearchView: View {
    @State private var searchText: String = ""
    @State private var searchResults: [Word] = []
    @State private var exactMatch: Word? = nil
    @State private var isSearching: Bool = false
    @State private var showResults: Bool = false
    @FocusState private var isFocused: Bool
    
    private let repository = WordRepository()
    
    var body: some View {
        VStack(spacing: 12) {
            searchField
        }
        .frame(maxWidth: 400)
        .overlay(alignment: .top) {
            if showResults && !searchText.isEmpty {
                searchResultsOverlay
                    .offset(y: 50)
            }
        }
        .onAppear {
            isFocused = true
        }
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索单词... (按ESC取消)", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isFocused)
                .onChange(of: searchText) { newValue in
                    if newValue.isEmpty {
                        searchResults = []
                        exactMatch = nil
                        showResults = false
                    } else {
                        performSearch()
                        showResults = true
                    }
                }
            if !searchText.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(10)
        .onExitCommand(perform: clearSearch)
    }
    
    private func clearSearch() {
        searchText = ""
        searchResults = []
        exactMatch = nil
        showResults = false
    }
    
    private var searchResultsOverlay: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let exact = exactMatch {
                    Text("精确匹配")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    
                    SearchResultRow(word: exact) {
                        TTSManager.shared.speak(exact.text)
                    }
                    Divider()
                }
                
                let partialResults = searchResults.filter { $0.id != exactMatch?.id }
                if !partialResults.isEmpty {
                    Text("相关结果")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    
                    ForEach(partialResults) { word in
                        SearchResultRow(word: word) {
                            TTSManager.shared.speak(word.text)
                        }
                        Divider()
                    }
                }
                
                if exactMatch == nil && searchResults.isEmpty && !searchText.isEmpty {
                    Text("未找到结果")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .frame(height: 250)
        .frame(maxWidth: 400)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        Task {
            isSearching = true
            do {
                let results = try await repository.searchWords(query: searchText)
                let query = searchText.lowercased()
                exactMatch = results.first { $0.text.lowercased() == query }
                searchResults = results
            } catch {
                Logger.error("搜索失败: \(error)")
            }
            isSearching = false
        }
    }
}

struct SearchResultRow: View {
    let word: Word
    let onSpeak: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(word.text)
                        .font(.system(size: 14, weight: .semibold))
                    if let ipa = word.ipa {
                        Text(ipa)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                if let meanings = word.meanings {
                    Text(meanings)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button(action: onSpeak) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowWordRootsDetail"),
                object: word
            )
        }
    }
}