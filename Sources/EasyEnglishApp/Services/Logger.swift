import Foundation
import os.log

/// 统一日志系统 - 替换 print 语句
struct Logger {
    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.easyenglish", category: "app")
    
    enum Level: String {
        case debug = "🔵"
        case info = "ℹ️"
        case warning = "⚠️"
        case error = "❌"
        case success = "✅"
        case performance = "⚡"
    }
    
    /// 调试日志 (仅在 DEBUG 模式显示)
    static func debug(_ message: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let location = "\(file.components(separatedBy: "/").last ?? file):\(line)"
        os_log("[DEBUG] %{public}@ - %{public}@", log: log, type: .debug, location, message)
        #endif
    }
    
    /// 信息日志
    static func info(_ message: String) {
        os_log("%{public}@", log: log, type: .info, message)
    }
    
    /// 警告日志
    static func warning(_ message: String, file: String = #file, line: Int = #line) {
        let location = "\(file.components(separatedBy: "/").last ?? file):\(line)"
        os_log("%{public}@ %{public}@", log: log, type: .fault, location, message)
    }
    
    /// 错误日志
    static func error(_ message: String, error: Error? = nil, file: String = #file, line: Int = #line) {
        let location = "\(file.components(separatedBy: "/").last ?? file):\(line)"
        let errorInfo = error != nil ? "Error: \(error!.localizedDescription)" : ""
        os_log("%{public}@ %{public}@", log: log, type: .error, location, message + " " + errorInfo)
    }
    
    /// 成功日志
    static func success(_ message: String) {
        os_log("%{public}@", log: log, type: .info, message)
    }
    
    /// 性能日志
    static func performance(_ message: String, duration: TimeInterval) {
        let formatted = duration.formattedSignificantDigits(3)
        os_log("%{public}@ %{public}@", log: log, type: .default, "\(formatted)s", message)
    }
    
    /// 测量执行时间
    static func measure(_ label: String, perform work: () throws -> Void) rethrows {
        let start = CFAbsoluteTimeGetCurrent()
        try work()
        let duration = CFAbsoluteTimeGetCurrent() - start
        performance(label, duration: duration)
    }
}

// MARK: - TimeInterval 扩展
extension TimeInterval {
    /// 格式化为指定有效数字位数
    func formattedSignificantDigits(_ digits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumSignificantDigits = digits
        return formatter.string(from: self as NSNumber) ?? "\(self)"
    }
}
