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
        // Check current permission status without requesting
        checkPermissionStatus()
    }

    func checkPermissionStatus() {
        // Check speech recognition status
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        isAuthorized = speechStatus == .authorized

        // Check microphone status
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        hasPermissions = isAuthorized && micStatus == .granted
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
            }
        }
    }
    
    func startRecording() {
        guard hasPermissions else {
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
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Add vocabulary hints for Arabic words to improve recognition accuracy
        recognitionRequest.contextualStrings = [
            "wallahi", "wallah", "walhi", "walha",
            "wallahi i prayed", "wallah i prayed", "walhi i prayed", "walha i prayed",
            "prayed", "prayer", "salah"
        ]
        
        // Create recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcript = result.bestTranscription.formattedString
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
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            transcript = ""
        } catch {
            // Audio engine failed to start
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
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Failed to deactivate audio session
        }
    }
    
    var isConfirmationCorrect: Bool {
        let normalizedTranscript = transcript
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-z ]", with: "", options: .regularExpression)
        
        
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
                break
            }
        }
        
        // Additional strict validation: ensure the phrase contains both wallahi AND prayed elements
        // but only accept if found as complete phrases, not individual words
        
        return isCorrect
    }
} 