import Foundation
import AppKit

final class SoundManager {
    static let shared = SoundManager()

    private var typingSound: NSSound?

    private init() {
        typingSound = Self.loadSound(named: "typing")
    }

    func playKeyClick() {
        if let sound = typingSound {
            let copy = sound.copy() as! NSSound
            copy.play()
        }
    }

    func playCorrect() {
        if let sound = typingSound {
            let copy = sound.copy() as! NSSound
            copy.play()
        }
    }

    func playError() {
        if let sound = NSSound(named: "Basso") {
            let copy = sound.copy() as! NSSound
            copy.play()
        }
    }

    private static func loadSound(named name: String) -> NSSound? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).mp3")
        try? data.write(to: tempDir)
        return NSSound(contentsOf: tempDir, byReference: true)
    }
}
