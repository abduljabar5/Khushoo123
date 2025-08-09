import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechRecognitionService: ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var isAuthorized = false
    @Published var hasPermissions = false
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    init() {
        requestPermissions()
    }
    
    func requestPermissions() {
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.isAuthorized = true
                    self?.requestMicrophonePermission()
                case .denied, .restricted, .notDetermined:
                    self?.isAuthorized = false
                    print("❌ [SpeechRecognition] Speech recognition not authorized: \(authStatus)")
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermissions = granted && (self?.isAuthorized ?? false)
                if granted {
                    print("✅ [SpeechRecognition] Microphone permission granted")
                } else {
                    print("❌ [SpeechRecognition] Microphone permission denied")
                }
            }
        }
    }
    
    func startRecording() {
        guard hasPermissions else {
            print("❌ [SpeechRecognition] No permissions to start recording")
            return
        }
        
        // Cancel any ongoing recognition
        stopRecording()
        
        // Reset audio engine if needed
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.reset()
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ [SpeechRecognition] Audio session setup failed: \(error)")
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ [SpeechRecognition] Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Add vocabulary hints for Arabic words to improve recognition accuracy
        recognitionRequest.contextualStrings = [
            "wallahi", "wallah", "walhi", "walha",
            "wallahi i prayed", "wallah i prayed", "walhi i prayed", "walha i prayed",
            "prayed", "prayer", "salah"
        ]
        
        print("✅ [SpeechRecognition] Added Arabic vocabulary hints to improve recognition")
        
        // Create recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcript = result.bestTranscription.formattedString
                    print("🎤 [SpeechRecognition] Transcript: \(result.bestTranscription.formattedString)")
                }
                
                if error != nil || result?.isFinal == true {
                    self?.stopRecording()
                }
            }
        }
        
        // Start audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Validate the format before using it
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            print("❌ [SpeechRecognition] Invalid audio format: \(recordingFormat)")
            print("❌ [SpeechRecognition] Sample rate: \(recordingFormat.sampleRate), Channels: \(recordingFormat.channelCount)")
            return
        }
        
        print("✅ [SpeechRecognition] Using audio format: \(recordingFormat)")
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            transcript = ""
            print("🎤 [SpeechRecognition] Started recording")
        } catch {
            print("❌ [SpeechRecognition] Audio engine failed to start: \(error)")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop audio engine safely
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove tap safely
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Clean up recognition objects
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
        print("🛑 [SpeechRecognition] Stopped recording")
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ [SpeechRecognition] Failed to deactivate audio session: \(error)")
        }
    }
    
    var isConfirmationCorrect: Bool {
        let normalizedTranscript = transcript
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-z ]", with: "", options: .regularExpression)
        
        print("🔍 [SpeechRecognition] Checking transcript: '\(normalizedTranscript)'")
        
        // We only check for complete phrases, not individual word variations
        
        // Only check for complete phrase variations (correct Arabic spellings)
        // Vocabulary hints should help speech recognition understand these correctly
        let completePhrasesVariations = [
            "wallahi i prayed", "wallah i prayed", "walhi i prayed", "walha i prayed",
            "wallahi prayed", "wallah prayed", "walhi prayed", "walha prayed"
        ]
        
        var isCorrect = false
        var matchedPhrase = ""
        
        for phrase in completePhrasesVariations {
            if normalizedTranscript.contains(phrase) {
                isCorrect = true
                matchedPhrase = phrase
                print("🎯 [SpeechRecognition] Found complete phrase: '\(phrase)'")
                break
            }
        }
        
        // Additional strict validation: ensure the phrase contains both wallahi AND prayed elements
        // but only accept if found as complete phrases, not individual words
        if isCorrect {
            print("✅ [SpeechRecognition] Valid complete phrase detected: '\(matchedPhrase)' in '\(transcript)'")
        }
        
        if !isCorrect {
            print("❌ [SpeechRecognition] Phrase not recognized: '\(transcript)' - must say complete phrase like 'Wallahi I prayed'")
        }
        
        return isCorrect
    }
} 