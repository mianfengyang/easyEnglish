import XCTest
@testable import EasyEnglish

final class SM2Tests: XCTestCase {
    
    // MARK: - 基本功能测试
    
    func testSM2InitialCorrectAnswer() {
        let (reps, interval, ef, next) = SM2.schedule(reps: 0, interval: 0, ef: 2.5, quality: 5)
        XCTAssertEqual(reps, 1, "第一次正确回忆，reps 应该为 1")
        XCTAssertEqual(interval, 1, "第一次复习间隔应该是 1 天")
        XCTAssertGreaterThanOrEqual(ef, 1.3, "EF 应该 >= 1.3")
        XCTAssertNotNil(next, "下次复习日期不应该为 nil")
    }
    
    func testSM2SecondReview() {
        let (reps, interval, _, _) = SM2.schedule(reps: 1, interval: 1, ef: 2.5, quality: 5)
        XCTAssertEqual(reps, 2, "第二次正确回忆，reps 应该为 2")
        XCTAssertEqual(interval, 6, "第二次复习间隔应该是 6 天")
    }
    
    func testSM2ThirdReviewAndBeyond() {
        // 第三次复习：间隔 = 6 * 2.5 = 15 天
        let (reps, interval, _, _) = SM2.schedule(reps: 2, interval: 6, ef: 2.5, quality: 5)
        XCTAssertEqual(reps, 3)
        XCTAssertEqual(interval, 15, "第三次复习间隔应该是 6 * 2.5 = 15 天")
    }
    
    // MARK: - 失败情况测试
    
    func testSM2FailureResets() {
        let (reps, interval, _, _) = SM2.schedule(reps: 5, interval: 30, ef: 2.5, quality: 0)
        XCTAssertEqual(reps, 0, "失败应该重置 reps")
        XCTAssertEqual(interval, 1, "失败应该重置间隔为 1 天")
    }
    
    func testSM2LowQuality() {
        let (reps, interval, _, _) = SM2.schedule(reps: 3, interval: 10, ef: 2.5, quality: 2)
        XCTAssertEqual(reps, 0, "quality < 3 应该视为失败")
        XCTAssertEqual(interval, 1)
    }
    
    // MARK: - EF 计算测试
    
    func testSM2EFDecreaseOnFailure() {
        let initialEF = 2.5
        let (_, _, newEF, _) = SM2.schedule(reps: 1, interval: 1, ef: initialEF, quality: 0)
        XCTAssertLessThan(newEF, initialEF, "失败时 EF 应该下降")
        XCTAssertGreaterThanOrEqual(newEF, 1.3, "EF 不应该低于 1.3")
    }
    
    func testSM2EFIncreaseOnSuccess() {
        let initialEF = 2.5
        let (_, _, newEF, _) = SM2.schedule(reps: 1, interval: 1, ef: initialEF, quality: 5)
        XCTAssertGreaterThanOrEqual(newEF, initialEF, "成功时 EF 应该增加或保持不变")
    }
    
    func testSM2EFMinimum() {
        // 极端情况：多次失败，EF 应该保持在 1.3
        var ef = 2.5
        for _ in 0..<10 {
            (_, _, ef, _) = SM2.schedule(reps: 1, interval: 1, ef: ef, quality: 0)
        }
        XCTAssertEqual(ef, 1.3, "EF 最低值为 1.3", accuracy: 0.01)
    }
    
    // MARK: - 边界值测试
    
    func testSM2QualityClamping() {
        // quality 超出范围应该被 clamped
        let result1 = SM2.schedule(reps: 0, interval: 0, ef: 2.5, quality: -5)
        let result2 = SM2.schedule(reps: 0, interval: 0, ef: 2.5, quality: 10)
        
        // -5 应该被 clamp 到 0，10 应该被 clamp 到 5
        // 两者都应该正常工作，不崩溃
        XCTAssertNotNil(result1.next)
        XCTAssertNotNil(result2.next)
    }
    
    func testSM2QualityThreshold() {
        // quality = 2 应该失败
        let (reps1, _, _, _) = SM2.schedule(reps: 1, interval: 1, ef: 2.5, quality: 2)
        XCTAssertEqual(reps1, 0)
        
        // quality = 3 应该成功
        let (reps2, _, _, _) = SM2.schedule(reps: 1, interval: 1, ef: 2.5, quality: 3)
        XCTAssertEqual(reps2, 2)
    }
    
    // MARK: - 性能测试
    
    func testSM2Performance() {
        let iterations = 1000
        let start = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            _ = SM2.schedule(reps: 1, interval: 1, ef: 2.5, quality: 4)
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - start
        XCTAssertLessThan(duration, 1.0, "\(iterations) 次迭代应该在 1 秒内完成")
        print("SM2 性能测试：\(iterations) 次迭代耗时 \(duration.formatted(.number.precision(.significantDigits(3)))) 秒")
    }
}

// MARK: - 辅助扩展

private extension Double {
    func formatted(_ style: NumberFormatter.Style) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = style
        return formatter.string(from: self as NSNumber) ?? "\(self)"
    }
}

extension NumberFormatter {
    enum Style {
        case significantDigits(Int)
        
        func format(_ value: Double) -> String {
            let formatter = NumberFormatter()
            if case .significantDigits(let digits) = self {
                formatter.maximumSignificantDigits = digits
            }
            return formatter.string(from: value as NSNumber) ?? "\(value)"
        }
    }
}
