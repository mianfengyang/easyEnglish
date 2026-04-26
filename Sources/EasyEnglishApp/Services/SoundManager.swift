import Foundation
import AudioToolbox
import AppKit

final class SoundManager {
    static let shared = SoundManager()
    
    private init() {}
    
    func playKeyClick() {
        if let sound = NSSound(named: "Typewriter") {
            let copy = sound.copy() as! NSSound
            copy.play()
        }
    }
    
    func playCorrect() {
        if let sound = NSSound(named: "Typewriter") {
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
}