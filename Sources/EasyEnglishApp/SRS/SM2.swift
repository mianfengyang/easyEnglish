import Foundation

/// SM-2 间隔重复算法实现
/// 
/// 参考：https://www.supermemo.com/en/archives1990-2015/english/ol/sm2
/// 
/// 算法核心：
/// - Quality 范围：0-5（5=完美回忆，0=完全忘记）
/// - EF (Easiness Factor) 范围：1.3-2.5+（越高表示越容易）
/// - 复习间隔随 reps 增加而增长
struct SM2 {
    
    // MARK: - 常量定义
    
    /// 最低 EF 值（SuperMemo 标准）
    private static let minEF = 1.3
    
    /// 初始 EF 值
    private static let initialEF = 2.5
    
    /// 质量阈值：>=3 视为正确回忆
    private static let qualityThreshold = 3
    
    /// 第一次复习间隔（天）
    private static let firstInterval = 1
    
    /// 第二次复习间隔（天）
    private static let secondInterval = 6
    
    /// 质量范围
    private static let minQuality = 0
    private static let maxQuality = 5
    
    // MARK: - 公共 API
    
    /// 计算下一次复习调度
    /// - Parameters:
    ///   - reps: 当前连续正确次数
    ///   - interval: 当前间隔天数
    ///   - ef: 当前 Easiness Factor
    ///   - quality: 回忆质量（0-5）
    /// - Returns: (新 reps, 新间隔天数，新 EF, 下次复习日期)
    static func schedule(reps: Int, interval: Int, ef: Double, quality: Int) -> (Int, Int, Double, Date?) {
        // 限制 quality 范围
        let q = quality.clamped(to: minQuality...maxQuality)
        
        var newReps = reps
        var newInterval = interval
        var newEF = ef
        
        if q < qualityThreshold {
            // 回忆失败：重置
            newReps = 0
            newInterval = firstInterval
        } else {
            // 回忆成功
            newReps += 1
            
            switch newReps {
            case 1:
                newInterval = firstInterval
            case 2:
                newInterval = secondInterval
            default:
                newInterval = Int(round(Double(newInterval) * newEF))
            }
        }
        
        // 更新 EF
        newEF = calculateNewEF(currentEF: ef, quality: q)
        
        let next = Calendar.current.date(byAdding: .day, value: newInterval, to: Date())
        return (newReps, newInterval, newEF, next)
    }
    
    // MARK: - 私有实现
    
    /// 计算新的 Easiness Factor
    private static func calculateNewEF(currentEF: Double, quality: Int) -> Double {
        let delta = 0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02)
        let newEF = currentEF + delta
        return max(minEF, newEF)
    }
}

// MARK: - 扩展

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        return Swift.min(Swift.max(range.lowerBound, self), range.upperBound)
    }
}
