import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack {
                Text("设置").font(.title2).bold()
                Spacer()
                Button("关闭") { dismiss() }
            }
            .frame(maxWidth: .infinity)
            
            Form {
                wordlistSection
                dailyNewWordsSection
                appearanceSection
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 480, minHeight: 300)
    }
    
    private var wordlistSection: some View {
        Section(header: Text("词库")) {
            let lists = settings.availableWordlists()
            if lists.isEmpty {
                Text("未发现 Data/wordlists 中的词库，请把词库放入该目录并重启应用。")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            } else {
                Picker("选择词库", selection: Binding(
                    get: { settings.selectedWordlist ?? "" },
                    set: { settings.selectedWordlist = $0.isEmpty ? nil : $0 }
                )) {
                    ForEach(lists, id: \.self) { name in
                        HStack {
                            Text(name)
                            if name.hasSuffix(".sqlite") {
                                Text("⚡️").font(.caption)
                            }
                        }
                        .tag(name)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                if let selected = settings.selectedWordlist {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("当前选择：\(selected)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if selected.hasSuffix(".sqlite") {
                            Text("✅ SQLite 数据库 - 极速加载")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.top, 4)
                }
                
                Button("刷新会话") {
                    NotificationCenter.default.post(name: NSNotification.Name("refreshSession"), object: nil)
                }
                .frame(maxWidth: .infinity)
                
                if settings.selectedWordlist?.hasSuffix(".sqlite") ?? false {
                    Text("💡 提示：SQLite 数据库已预编译，直接刷新会话即可使用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    private var dailyNewWordsSection: some View {
        Section(header: Text("每日新词")) {
            Stepper(value: $settings.dailyNewLimit, in: 1...200) {
                Text("每天新词：\(settings.dailyNewLimit)")
            }
        }
    }
    
    private var appearanceSection: some View {
        Section(header: Text("外观")) {
            Picker("主题模式", selection: $settings.themeMode) {
                ForEach(ThemeMode.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Text("当前主题：\(settings.themeMode.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
}