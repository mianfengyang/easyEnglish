import XCTest
import os.log
@testable import EasyEnglish

final class LoggerTests: XCTestCase {
    
    func testLoggerInitialization() {
        // 测试 Logger 可以正常初始化
        let log = OSLog(subsystem: "com.easyenglish", category: "app")
        XCTAssertFalse(log.description.isEmpty)
    }
    
    func testLogLevelEnum() {
        // 测试所有日志级别
        XCTAssertEqual(Logger.Level.debug.rawValue, "🔵")
        XCTAssertEqual(Logger.Level.info.rawValue, "ℹ️")
        XCTAssertEqual(Logger.Level.warning.rawValue, "⚠️")
        XCTAssertEqual(Logger.Level.error.rawValue, "❌")
        XCTAssertEqual(Logger.Level.success.rawValue, "✅")
        XCTAssertEqual(Logger.Level.performance.rawValue, "⚡")
    }
    
    func testLoggerInfo() {
        // 测试 info 日志不抛出异常
        XCTAssertNoThrow(Logger.info("Test info message"))
    }
    
    func testLoggerSuccess() {
        // 测试 success 日志不抛出异常
        XCTAssertNoThrow(Logger.success("Test success message"))
    }
    
    func testLoggerWarning() {
        // 测试 warning 日志不抛出异常
        XCTAssertNoThrow(Logger.warning("Test warning message"))
    }
    
    func testLoggerError() {
        // 测试 error 日志不抛出异常
        let testError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        XCTAssertNoThrow(Logger.error("Test error message", error: testError))
    }
    
    func testLoggerMeasure() {
        // 测试性能测量功能
        var executed = false
        Logger.measure("Test operation") {
            executed = true
            Thread.sleep(forTimeInterval: 0.01)
        }
        XCTAssertTrue(executed)
    }
    
    func testTimeIntervalFormatting() {
        // 测试 TimeInterval 格式化
        let duration: TimeInterval = 1.234567
        let formatted = duration.formattedSignificantDigits(3)
        XCTAssertEqual(formatted, "1.23")
    }
}
