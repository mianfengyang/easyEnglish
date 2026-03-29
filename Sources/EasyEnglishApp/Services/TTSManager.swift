import Foundation
import AVFoundation
import Combine

@MainActor
final class TTSManager: NSObject, ObservableObject {
    static let shared = TTSManager()

    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking: Bool = false
    
    // 缓存常用语音，减少系统查找开销
    private var englishVoice: AVSpeechSynthesisVoice?
    private var chineseVoice: AVSpeechSynthesisVoice?

    private override init() {
        super.init()
        synthesizer.delegate = self
        
        // 预加载常用语音（使用两位语言代码，避免系统警告）
        englishVoice = AVSpeechSynthesisVoice(language: "en")
        chineseVoice = AVSpeechSynthesisVoice(language: "zh")
        
        Logger.info("TTSManager 初始化完成，已预加载语音")
    }

    /// 播放文本发音
    /// - Parameters:
    ///   - text: 要播放的文本
    ///   - language: 语言代码（推荐使用两位代码，如"en"、"zh"，避免使用"en-US"、"zh-CN"）
    ///   - rate: 语速（默认正常速度）
    func speak(_ text: String, language: String = "en", rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        guard !text.isEmpty else { return }
        
        stop()
        
        let utterance = AVSpeechUtterance(string: text)
        
        // 优先使用缓存的语音，如果没有则动态创建
        if language.lowercased().hasPrefix("en") {
            utterance.voice = englishVoice ?? AVSpeechSynthesisVoice(language: "en")
        } else if language.lowercased().hasPrefix("zh") {
            utterance.voice = chineseVoice ?? AVSpeechSynthesisVoice(language: "zh")
        } else {
            // 其他语言直接创建（避免使用四位代码如 zh-CN）
            let normalizedLanguage = normalizeLanguageCode(language)
            utterance.voice = AVSpeechSynthesisVoice(language: normalizedLanguage)
        }
        
        utterance.rate = rate
        synthesizer.speak(utterance)
        
        Logger.debug("播放发音：\(text), 语言：\(language)")
    }
    
    /// 标准化语言代码（将四位代码转换为两位代码）
    /// - Parameter code: 原始语言代码
    /// - Returns: 标准化后的两位语言代码
    private func normalizeLanguageCode(_ code: String) -> String {
        // 如果是四位代码（如 en-US, zh-CN），只取前两位
        if code.count >= 2 {
            let prefix = String(code.prefix(2)).lowercased()
            // 验证是否是有效的 ISO 639 语言代码
            switch prefix {
            case "en", "zh", "ja", "ko", "fr", "de", "es", "it", "pt", "ru":
                return prefix
            default:
                // 未知语言，返回英语作为默认值
                return "en"
            }
        }
        return "en"
    }
    
    /// 检查是否有可用的中文语音
    func hasChineseVoice() -> Bool {
        return chineseVoice != nil || AVSpeechSynthesisVoice(language: "zh") != nil
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}

extension TTSManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in self?.isSpeaking = true }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in self?.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in self?.isSpeaking = false }
    }
}
