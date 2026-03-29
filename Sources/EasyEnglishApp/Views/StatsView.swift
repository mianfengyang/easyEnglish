import SwiftUI

struct StatsView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    // ✅ 添加回调闭包，用于通知父视图重新学习
    var onRestartLearning: (() -> Void)?

    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack {
                // ✅ 已移除"学习统计"标题
                Spacer()
                Button("关闭") { 
                    // ✅ 点击关闭时触发重新学习
                    onRestartLearning?()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                DatePicker("开始", selection: $startDate, displayedComponents: .date)
                DatePicker("结束", selection: $endDate, displayedComponents: .date)
                Button("导出 CSV") { exportCSV() }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)

            // 暂时禁用图表，等待 SQLite 实现
            VStack(alignment: .center) {
                Text("每日练习次数（功能开发中）").font(.headline)
                Text("统计功能暂时禁用，正在适配新的数据库架构")
                    .foregroundColor(.secondary)
                    .padding()
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)

            VStack(alignment: .center) {
                Text("保留率（quality ≥ 3 的比例）")
                    .font(.headline)
                Text("统计功能暂时禁用，正在适配新的数据库架构")
                    .foregroundColor(.secondary)
                    .padding()
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)

            Divider()

            // 暂时显示空列表提示
            List {
                HStack {
                    Spacer()
                    Text("📊 学习记录功能正在适配新的数据库架构\n请稍后使用基础学习功能")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 480)
        .alert("提示", isPresented: $showAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }

    private func exportCSV() {
        showAlert = true
        alertMessage = "CSV 导出功能正在适配新的数据库架构"
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
    }
}
