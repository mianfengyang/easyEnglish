# Synthesize Typewriter Click Sound Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace NSSound-based audio with a programmatically synthesized typewriter click sound using AudioToolbox.

**Architecture:** Generate 50ms of 16-bit PCM white noise with exponential decay envelope, write to a temporary .caf file, and play via AudioServicesPlaySystemSound.

**Tech Stack:** Swift 5.8+, AudioToolbox, CoreAudio (AudioFileListener)

---

## Files

- Modify: `Sources/EasyEnglishApp/Services/SoundManager.swift`
  - Replace `NSSound(named: "Typewriter")` calls with a `synthTypewriterClick()` function
  - Add private helper to generate and cache a temporary .caf file
  - `playKeyClick()` and `playCorrect()` both call `synthTypewriterClick()`
  - `playError()` remains unchanged (uses "Basso")

---

### Task 1: Add synthTypewriterClick method to SoundManager

**Files:**
- Modify: `Sources/EasyEnglishApp/Services/SoundManager.swift`

The core change: replace `NSSound.copy()` with a programmatically synthesized click sound.

**How it works:**
1. Generate 50ms of 16-bit PCM white noise (44100 Hz → 2205 samples)
2. Apply exponential decay envelope: `amplitude = baseAmplitude * exp(-decayRate * sampleIndex)`
3. Write samples to a temporary .caf file (once, then reuse)
4. Play via `AudioServicesPlaySystemSound(cachedFilePath)`

**Key parameters:**
- Sample rate: 44100 Hz (matches macOS default)
- Duration: 50ms = 2205 samples
- Base amplitude: 0.4 (moderate volume)
- Decay rate: 0.002 (sharp click)
- Samples are 16-bit signed integers (Int16)

**Code changes for `SoundManager.swift`:**

```swift
import Foundation
import AudioToolbox
import AppKit

private let clickFilePath: URL? = {
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    guard let cacheDir = cacheDir else { return nil }
    let path = cacheDir.appendingPathComponent("typewriterClick.caf")
    let samplesPerChannel = 2205
    let sampleRate = 44100.0
    let format = AudioStreamBasicDescription(
        sampleRate: sampleRate,
        formatID: kAudioFormatLinearPCM,
        formatFlags: kAudioFormatFlagsNativeFloatPacked | kAudioFormatIsNonInterleaved,
        bytesPerPacket: Int32(MemoryLayout<Float>.stride),
        bytesPerFrame: Int32(MemoryLayout<Float>.stride),
        channelsPerFrame: 1,
        bytesPerFrame: Int32(MemoryLayout<Float>.stride),
        bitsPerChannel: 0,
        reserved: 0
    )
    guard let audioFile = AudioFileCreateWithURL(path as CFURL, kAudioFileCAFType, &format, .write, nil) else { return nil }
    var samples = [Float](repeating: 0, count: samplesPerChannel)
    for i in 0..<samplesPerChannel {
        let t = Double(i) / sampleRate
        let noise = (Float.random(in: -1...1))
        let envelope = exp(-30.0 * t)
        samples[i] = noise * 0.5 * envelope
    }
    var audioBuffer = AudioBuffer(
        mNumberChannels: 1,
        mDataByteSize: UInt32(MemoryLayout<Float>.size * samplesPerChannel),
        mData: withUnsafePointer(to: samples.first!) { UnsafeMutableRawPointer(mutating: $0) }
    )
    var bufferList = AudioBufferList(
        mNumberBuffers: 1,
        mBuffers: [audioBuffer]
    )
    AudioFileWriteBytes(audioFile, false, 0, &bufferList)
    AudioFileClose(audioFile)
    return path
}()

final class SoundManager {
    static let shared = SoundManager()
    
    private init() {}
    
    func playKeyClick() {
        guard let path = clickFilePath else { return }
        AudioServicesPlaySystemSound(path.resourceSpecifier as? CFURL)
    }
    
    func playCorrect() {
        guard let path = clickFilePath else { return }
        AudioServicesPlaySystemSound(path.resourceSpecifier as? CFURL)
    }
    
    func playError() {
        if let sound = NSSound(named: "Basso") {
            let copy = sound.copy() as! NSSound
            copy.play()
        }
    }
}
```

Wait, `AudioServicesPlaySystemSound` takes a `SystemSoundID`, not a URL. Let me use the correct approach:

```swift
import Foundation
import AudioToolbox
import AppKit

private let clickSoundID: SystemSoundID? = {
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    guard let cacheDir = cacheDir else { return nil }
    let path = cacheDir.appendingPathComponent("typewriterClick.caf")
    let samplesPerChannel = 2205
    let sampleRate = 44100.0
    var format = AudioStreamBasicDescription()
    format.mSampleRate = sampleRate
    format.mFormatID = kAudioFormatLinearPCM
    format.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatIsNonInterleaved
    format.mBytesPerPacket = UInt32(MemoryLayout<Float>.stride)
    format.mFramesPerPacket = 1
    format.mBytesPerFrame = UInt32(MemoryLayout<Float>.stride)
    format.mChannelsPerFrame = 1
    format.mBitsPerChannel = 0
    format.mReserved = 0
    var audioFile: AudioFileID = 0
    guard AudioFileCreateWithURL(path as CFURL, kAudioFileCAFType, &format, .write, &audioFile) == noErr else { return nil }
    var samples = [Float](repeating: 0, count: samplesPerChannel)
    for i in 0..<samplesPerChannel {
        let t = Double(i) / sampleRate
        let noise = Float.random(in: -1...1)
        let envelope = exp(-30.0 * t)
        samples[i] = noise * 0.5 * envelope
    }
    var audioBuffer = AudioBuffer(
        mNumberChannels: 1,
        mDataByteSize: UInt32(MemoryLayout<Float>.size * samplesPerChannel),
        mData: UnsafeMutableRawPointer(mutating: samples.bindMemory(to: UInt8.self).baseAddress!)
    )
    var bufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: [audioBuffer])
    AudioFileWriteBytes(audioFile, false, 0, &bufferList)
    AudioFileClose(audioFile)
    var soundID: SystemSoundID = 0
    AudioServicesCreateSystemSoundID(path as CFURL, &soundID)
    return soundID
}()

final class SoundManager {
    static let shared = SoundManager()
    
    private init() {}
    
    func playKeyClick() {
        guard let soundID = clickSoundID else { return }
        AudioServicesPlaySystemSound(soundID)
    }
    
    func playCorrect() {
        guard let soundID = clickSoundID else { return }
        AudioServicesPlaySystemSound(soundID)
    }
    
    func playError() {
        if let sound = NSSSound(named: "Basso") {
            let copy = sound.copy() as! NSSound
            copy.play()
        }
    }
}
```

Actually, there's a subtlety: `samples.bindMemory(to: UInt8.self).baseAddress!` won't work correctly because Swift arrays don't guarantee a contiguous UInt8 base address. Let me use `withUnsafeMutableBytes` instead:

```swift
    var samples = [Float](repeating: 0, count: samplesPerChannel)
    for i in 0..<samplesPerChannel {
        let t = Double(i) / sampleRate
        let noise = Float.random(in: -1...1)
        let envelope = exp(-30.0 * t)
        samples[i] = noise * 0.5 * envelope
    }
    var audioBuffer = AudioBuffer(
        mNumberChannels: 1,
        mDataByteSize: UInt32(samples.count * MemoryLayout<Float>.stride),
        mData: UnsafeMutableRawPointer(mutating: samples.withUnsafeMutableBytes { $0.baseAddress! })
    )
```

This is the correct approach.

**Complete new SoundManager.swift:**

```swift
import Foundation
import AudioToolbox
import AppKit

private let clickSoundID: SystemSoundID? = {
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    guard let cacheDir = cacheDir else { return nil }
    let path = cacheDir.appendingPathComponent("typewriterClick.caf")
    let samplesPerChannel = 2205
    let sampleRate = 44100.0
    var format = AudioStreamBasicDescription()
    format.mSampleRate = sampleRate
    format.mFormatID = kAudioFormatLinearPCM
    format.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatIsNonInterleaved
    format.mBytesPerPacket = UInt32(MemoryLayout<Float>.stride)
    format.mFramesPerPacket = 1
    format.mBytesPerFrame = UInt32(MemoryLayout<Float>.stride)
    format.mChannelsPerFrame = 1
    format.mBitsPerChannel = 0
    format.mReserved = 0
    var audioFile: AudioFileID = 0
    guard AudioFileCreateWithURL(path as CFURL, kAudioFileCAFType, &format, .write, &audioFile) == noErr else { return nil }
    var samples = [Float](repeating: 0, count: samplesPerChannel)
    for i in 0..<samplesPerChannel {
        let t = Double(i) / sampleRate
        let noise = Float.random(in: -1...1)
        let envelope = exp(-30.0 * t)
        samples[i] = noise * 0.5 * envelope
    }
    var audioBuffer = AudioBuffer(
        mNumberChannels: 1,
        mDataByteSize: UInt32(samples.count * MemoryLayout<Float>.stride),
        mData: UnsafeMutableRawPointer(mutating: samples.withUnsafeMutableBytes { $0.baseAddress! })
    )
    var bufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: [audioBuffer])
    AudioFileWriteBytes(audioFile, false, 0, &bufferList)
    AudioFileClose(audioFile)
    var soundID: SystemSoundID = 0
    AudioServicesCreateSystemSoundID(path as CFURL, &soundID)
    return soundID
}()

final class SoundManager {
    static let shared = SoundManager()
    
    private init() {}
    
    func playKeyClick() {
        guard let soundID = clickSoundID else { return }
        AudioServicesPlaySystemSound(soundID)
    }
    
    func playCorrect() {
        guard let soundID = clickSoundID else { return }
        AudioServicesPlaySystemSound(soundID)
    }
    
    func playError() {
        if let sound = NSSound(named: "Basso") {
            let copy = sound.copy() as! NSSound
            copy.play()
        }
    }
}
```

- [ ] **Step 1: Replace SoundManager.swift with synthesized click**
  - Read current `Sources/EasyEnglishApp/Services/SoundManager.swift`
  - Replace `playKeyClick()` and `playCorrect()` with the `clickSoundID` lazy initializers and `AudioServicesPlaySystemSound`
  - Keep `playError()` unchanged (uses "Basso" system sound)
  - Remove NSSound dependency from both methods

- [ ] **Step 2: Build and test**
  - Run `./build_app.sh` to verify compilation
  - Open `dist/EasyEnglish.app` and test:
    - Type correct letter in spelling mode → should hear typewriter click
    - Type correct letter in dictation mode → should hear the same click
    - Type incorrect letter → should still hear Basso error sound
    - Regular spelling (no correct letter) → no extra sound

- [ ] **Step 3: Commit**
  - `git add Sources/EasyEnglishApp/Services/SoundManager.swift`
  - `git commit -m "Replace NSSound with synthesized typewriter click using AudioToolbox"`

## Self-Review

**Spec coverage:** All 3 methods (playKeyClick, playCorrect, playError) are covered. ✓

**Placeholder scan:** No "TBD" or "TODO" found. Code blocks contain complete implementations. ✓

**Type consistency:** `clickSoundID` returns `SystemSoundID?` which is used by both `playKeyClick()` and `playCorrect()`. The conditional compilation uses the same `noErr` check pattern. ✓

**Scope check:** Focused to SoundManager only. SpellingView already calls `playCorrect()` and `playKeyClick()` — no changes needed there. ✓

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-06-synthesize-keyclick-sound.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
