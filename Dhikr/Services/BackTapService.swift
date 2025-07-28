import Foundation
import UIKit
import SwiftUI
import CoreMotion

class BackTapService: ObservableObject {
    static let shared = BackTapService()
    
    private let dhikrService = DhikrService.shared
    private let motionManager = CMMotionManager()
    
    @Published var isEnabled = false
    @Published var isAvailable = false
    @Published var debugInfo = ""
    @Published var detectionMode: DetectionMode = .shake
    @Published var debugLoggingEnabled = true // Toggle for debug logging - enabled by default for testing
    
    enum DetectionMode: String, CaseIterable {
        case shake = "Shake"
        case backTap = "Back Tap"
        case both = "Both"
    }
    
    // Configuration for back tap types
    @Published var singleTapType: DhikrType = .astaghfirullah  // Most common
    @Published var doubleTapType: DhikrType = .subhanAllah     // Second most common
    @Published var tripleTapType: DhikrType = .alhamdulillah   // Third most common
    
    // Motion detection properties
    private var lastTapTime: Date?
    private var currentTapCount = 0
    private var isDetecting = false
    private let tapThreshold: TimeInterval = 0.8 // Time window for multiple taps
    private let debounceTime: TimeInterval = 0.1 // Prevent multiple triggers
    
    // Detection thresholds
    private let shakeThreshold: Double = 0.15 // Even more sensitive for general shaking
    private let backTapThreshold: Double = 0.08 // Even more sensitive for back taps
    private let backTapMaxDuration: TimeInterval = 0.8 // Longer duration to catch very subtle taps
    private let backTapMinDuration: TimeInterval = 0.05 // Minimum duration for a valid tap
    private let backTapCooldown: TimeInterval = 0.5 // Cooldown between detections
    private let ambientMotionThreshold: Double = 0.01 // Much lower threshold to allow more motion through
    
    // Debug properties
    private var debugCounter = 0
    private var lastAcceleration: Double = 0
    private var motionStartTime: Date?
    private var isInMotion = false
    private var tapSequenceTimer: Timer?
    private var lastSignificantLogTime: Date = Date()
    private let logCooldown: TimeInterval = 0.5 // Reduced cooldown for more frequent logging
    
    private init() {
        print("🔧 [BackTapService] Initializing...")
        checkBackTapAvailability()
        // Don't start motion detection immediately - wait for user to enable
        loadConfiguration()
        print("🔧 [BackTapService] Initialization complete")
        print("🔧 [BackTapService] Debug logging: \(debugLoggingEnabled)")
        print("🔧 [BackTapService] Ambient threshold: \(ambientMotionThreshold)")
        print("🔧 [BackTapService] Back tap threshold: \(backTapThreshold)")
        print("🔧 [BackTapService] Shake threshold: \(shakeThreshold)")
    }
    
    func enable() {
        guard isAvailable else {
            print("⚠️ [BackTapService] Back tap not available on this device")
            debugInfo = "Motion detection not available on this device"
            return
        }
        
        isEnabled = true
        UserDefaults.standard.set(true, forKey: "backTapEnabled")
        startMotionDetection()
        print("✅ [BackTapService] Back tap detection enabled")
        debugInfo = "Back tap detection is now active"
    }
    
    func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: "backTapEnabled")
        stopMotionDetection()
        print("❌ [BackTapService] Back tap detection disabled")
        debugInfo = "Back tap detection disabled"
    }
    
    private func checkBackTapAvailability() {
        // Check if device supports motion detection
        isAvailable = motionManager.isDeviceMotionAvailable
        
        // Load saved preference
        isEnabled = UserDefaults.standard.bool(forKey: "backTapEnabled")
        
        print("📱 [BackTapService] Device motion available: \(isAvailable)")
        print("📱 [BackTapService] Device motion active: \(motionManager.isDeviceMotionActive)")
        print("📱 [BackTapService] Accelerometer available: \(motionManager.isAccelerometerAvailable)")
        print("📱 [BackTapService] Gyroscope available: \(motionManager.isGyroAvailable)")
        
        debugInfo = """
        Device Motion Available: \(isAvailable)
        Device Motion Active: \(motionManager.isDeviceMotionActive)
        Accelerometer Available: \(motionManager.isAccelerometerAvailable)
        Gyroscope Available: \(motionManager.isGyroAvailable)
        Detection Mode: \(detectionMode.rawValue)
        """
    }
    
    private func setupMotionDetection() {
        guard isAvailable else { 
            print("❌ [BackTapService] Cannot setup motion detection - not available")
            return 
        }
        
        motionManager.deviceMotionUpdateInterval = 0.05 // 20 times per second for better detection
        print("✅ [BackTapService] Motion detection setup complete")
        print("✅ [BackTapService] Update interval: \(motionManager.deviceMotionUpdateInterval)s")
    }
    
    private func startMotionDetection() {
        guard isEnabled && isAvailable else { 
            print("❌ [BackTapService] Cannot start motion detection - enabled: \(isEnabled), available: \(isAvailable)")
            return 
        }
        
        print("🚀 [BackTapService] Starting motion detection...")
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ [BackTapService] Motion detection error: \(error)")
                return
            }
            
            guard let motion = motion else { return }
            
            // Calculate total acceleration
            let acceleration = sqrt(
                pow(motion.userAcceleration.x, 2) +
                pow(motion.userAcceleration.y, 2) +
                pow(motion.userAcceleration.z, 2)
            )
            
            // Only process if acceleration is above ambient motion threshold
            guard acceleration > ambientMotionThreshold else { return }
            
            // Debug logging only for significant motion and with cooldown
            let now = Date()
            if debugLoggingEnabled && acceleration > ambientMotionThreshold && now.timeIntervalSince(lastSignificantLogTime) > logCooldown {
                print("📊 [BackTapService] Motion detected - Acceleration: \(acceleration), Threshold: \(getCurrentThreshold())")
                print("📊 [BackTapService] X: \(motion.userAcceleration.x), Y: \(motion.userAcceleration.y), Z: \(motion.userAcceleration.z)")
                lastSignificantLogTime = now
            }
            
            // Detect motion based on mode
            handleMotionUpdate(acceleration, x: motion.userAcceleration.x, y: motion.userAcceleration.y, z: motion.userAcceleration.z)
            
            lastAcceleration = acceleration
        }
        
        print("✅ [BackTapService] Motion detection started successfully")
    }
    
    private func getCurrentThreshold() -> Double {
        switch detectionMode {
        case .shake:
            return shakeThreshold
        case .backTap:
            return backTapThreshold
        case .both:
            return min(shakeThreshold, backTapThreshold)
        }
    }
    
    private func handleMotionUpdate(_ acceleration: Double, x: Double, y: Double, z: Double) {
        // Determine which detection(s) to process
        switch detectionMode {
        case .shake:
            let threshold = shakeThreshold
            if !isInMotion && acceleration > threshold {
                isInMotion = true
                motionStartTime = Date()
                print("🎯 [BackTapService] Shake motion started - Acceleration: \(acceleration)")
            }
            if isInMotion && acceleration < threshold * 0.1 {
                if let startTime = motionStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    print("🎯 [BackTapService] Shake motion ended - Duration: \(duration)s")
                    if duration > 0.03 && duration < 2.0 {
                        handleShake()
                    }
                }
                isInMotion = false
                motionStartTime = nil
            }
        case .backTap:
            let threshold = backTapThreshold
            if !isInMotion && acceleration > threshold {
                isInMotion = true
                motionStartTime = Date()
                print("🎯 [BackTapService] Back tap motion started - Acceleration: \(acceleration)")
            }
            if isInMotion && acceleration < threshold * 0.1 {
                if let startTime = motionStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    print("🎯 [BackTapService] Back tap motion ended - Duration: \(duration)s")
                    if duration >= backTapMinDuration && duration <= backTapMaxDuration {
                        handleBackTap()
                    } else {
                        print("⏱️ [BackTapService] Motion duration \(duration)s outside valid range (\(backTapMinDuration)-\(backTapMaxDuration)s)")
                    }
                }
                isInMotion = false
                motionStartTime = nil
            }
        case .both:
            // Process both shake and back tap
            let shakeThresh = shakeThreshold
            let backTapThresh = backTapThreshold
            if !isInMotion && (acceleration > shakeThresh || acceleration > backTapThresh) {
                isInMotion = true
                motionStartTime = Date()
                print("🎯 [BackTapService] Both motion started - Acceleration: \(acceleration)")
            }
            if isInMotion && acceleration < min(shakeThresh, backTapThresh) * 0.1 {
                if let startTime = motionStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    print("🎯 [BackTapService] Both motion ended - Duration: \(duration)s")
                    if duration > 0.03 && duration < 2.0 {
                        handleShake()
                    }
                    if duration >= backTapMinDuration && duration <= backTapMaxDuration {
                        handleBackTap()
                    }
                }
                isInMotion = false
                motionStartTime = nil
            }
        }
    }
    
    private func handleShake() {
        guard !isDetecting else { return }
        isDetecting = true
        
        print("📱 [BackTapService] Shake detected!")
        incrementDhikr(singleTapType)
        
        // Reset after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isDetecting = false
        }
    }
    
    private func handleBackTap() {
        let now = Date()
        let timeSinceLastTap = lastTapTime != nil ? now.timeIntervalSince(lastTapTime!) : Double.infinity
        
        print("👆 [BackTapService] Back tap detected - time since last: \(timeSinceLastTap)s")
        
        if timeSinceLastTap < tapThreshold {
            // Multiple taps detected
            currentTapCount += 1
            print("👆 [BackTapService] Multiple tap detected - count: \(currentTapCount)")
        } else {
            // New tap sequence
            currentTapCount = 1
            print("👆 [BackTapService] New tap sequence started")
        }
        
        // Update last tap time
        lastTapTime = now
        
        // Cancel existing timer and start new one
        tapSequenceTimer?.invalidate()
        tapSequenceTimer = Timer.scheduledTimer(withTimeInterval: tapThreshold, repeats: false) { _ in
            self.processTapSequence()
        }
    }
    
    private func stopMotionDetection() {
        print("🛑 [BackTapService] Stopping motion detection...")
        motionManager.stopDeviceMotionUpdates()
        print("✅ [BackTapService] Motion detection stopped")
    }
    
    private func processTapSequence() {
        print("🎯 [BackTapService] Processing tap sequence - count: \(currentTapCount)")
        
        switch currentTapCount {
        case 1:
            incrementDhikr(singleTapType)
            print("✅ [BackTapService] Single tap processed - \(singleTapType.rawValue)")
        case 2:
            incrementDhikr(doubleTapType)
            print("✅ [BackTapService] Double tap processed - \(doubleTapType.rawValue)")
        case 3:
            incrementDhikr(tripleTapType)
            print("✅ [BackTapService] Triple tap processed - \(tripleTapType.rawValue)")
        default:
            print("⚠️ [BackTapService] Ignoring \(currentTapCount) taps (too many)")
            break
        }
        
        currentTapCount = 0
    }
    
    // Manual trigger methods for testing and development
    func triggerSingleTap() {
        guard isEnabled else { 
            print("❌ [BackTapService] Cannot trigger - not enabled")
            return 
        }
        incrementDhikr(singleTapType)
        print("✅ [BackTapService] Single tap triggered manually - \(singleTapType.rawValue)")
    }
    
    func triggerDoubleTap() {
        guard isEnabled else { 
            print("❌ [BackTapService] Cannot trigger - not enabled")
            return 
        }
        incrementDhikr(doubleTapType)
        print("✅ [BackTapService] Double tap triggered manually - \(doubleTapType.rawValue)")
    }
    
    func triggerTripleTap() {
        guard isEnabled else { 
            print("❌ [BackTapService] Cannot trigger - not enabled")
            return 
        }
        incrementDhikr(tripleTapType)
        print("✅ [BackTapService] Triple tap triggered manually - \(tripleTapType.rawValue)")
    }
    
    private func incrementDhikr(_ type: DhikrType) {
        print("📈 [BackTapService] Incrementing dhikr: \(type.rawValue)")
        dhikrService.incrementDhikr(type)
        showBackTapFeedback(for: type)
    }
    
    private func showBackTapFeedback(for type: DhikrType) {
        // Haptic feedback
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        
        // Post notification for UI updates
        NotificationCenter.default.post(
            name: .backTapDhikrAdded,
            object: type,
            userInfo: ["dhikrType": type]
        )
        
        print("📳 [BackTapService] Haptic feedback sent for \(type.rawValue)")
    }
    
    // Configuration methods
    func setDetectionMode(_ mode: DetectionMode) {
        detectionMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "detectionMode")
        print("⚙️ [BackTapService] Detection mode set to: \(mode.rawValue)")
        updateDebugInfo()
    }
    
    func setSingleTapAction(_ type: DhikrType) {
        singleTapType = type
        UserDefaults.standard.set(type.rawValue, forKey: "singleTapAction")
        print("⚙️ [BackTapService] Single tap action set to: \(type.rawValue)")
    }
    
    func setDoubleTapAction(_ type: DhikrType) {
        doubleTapType = type
        UserDefaults.standard.set(type.rawValue, forKey: "doubleTapAction")
        print("⚙️ [BackTapService] Double tap action set to: \(type.rawValue)")
    }
    
    func setTripleTapAction(_ type: DhikrType) {
        tripleTapType = type
        UserDefaults.standard.set(type.rawValue, forKey: "tripleTapAction")
        print("⚙️ [BackTapService] Triple tap action set to: \(type.rawValue)")
    }
    
    func toggleDebugLogging() {
        debugLoggingEnabled.toggle()
        UserDefaults.standard.set(debugLoggingEnabled, forKey: "debugLoggingEnabled")
        print("🔍 [BackTapService] Debug logging \(debugLoggingEnabled ? "enabled" : "disabled")")
        updateDebugInfo()
    }
    
    private func updateDebugInfo() {
        debugInfo = """
        Device Motion Available: \(isAvailable)
        Device Motion Active: \(motionManager.isDeviceMotionActive)
        Accelerometer Available: \(motionManager.isAccelerometerAvailable)
        Gyroscope Available: \(motionManager.isGyroAvailable)
        Detection Mode: \(detectionMode.rawValue)
        Shake Threshold: \(shakeThreshold)
        Back Tap Threshold: \(backTapThreshold)
        Ambient Motion Threshold: \(ambientMotionThreshold)
        Debug Logging: \(debugLoggingEnabled ? "ON" : "OFF")
        """
    }
    
    func loadConfiguration() {
        print("📂 [BackTapService] Loading configuration...")
        
        // Load detection mode
        if let modeString = UserDefaults.standard.string(forKey: "detectionMode"),
           let mode = DetectionMode(rawValue: modeString) {
            self.detectionMode = mode
            print("📂 [BackTapService] Loaded detection mode: \(mode.rawValue)")
        }
        
        if let singleTapString = UserDefaults.standard.string(forKey: "singleTapAction"),
           let singleTapType = DhikrType(rawValue: singleTapString) {
            self.singleTapType = singleTapType
            print("📂 [BackTapService] Loaded single tap: \(singleTapType.rawValue)")
        }
        
        if let doubleTapString = UserDefaults.standard.string(forKey: "doubleTapAction"),
           let doubleTapType = DhikrType(rawValue: doubleTapString) {
            self.doubleTapType = doubleTapType
            print("📂 [BackTapService] Loaded double tap: \(doubleTapType.rawValue)")
        }
        
        if let tripleTapString = UserDefaults.standard.string(forKey: "tripleTapAction"),
           let tripleTapType = DhikrType(rawValue: tripleTapString) {
            self.tripleTapType = tripleTapType
            print("📂 [BackTapService] Loaded triple tap: \(tripleTapType.rawValue)")
        }
        
        // Load debug logging preference
        debugLoggingEnabled = UserDefaults.standard.bool(forKey: "debugLoggingEnabled")
        print("📂 [BackTapService] Debug logging: \(debugLoggingEnabled ? "enabled" : "disabled")")
        
        updateDebugInfo()
    }
    
    deinit {
        stopMotionDetection()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let backTapDhikrAdded = Notification.Name("backTapDhikrAdded")
}

// MARK: - Back Tap Configuration View
struct BackTapSettingsView: View {
    @ObservedObject var backTapService = BackTapService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Motion Detection")
                        Spacer()
                        Toggle("", isOn: $backTapService.isEnabled)
                            .onChange(of: backTapService.isEnabled) { newValue in
                                if newValue {
                                    backTapService.enable()
                                } else {
                                    backTapService.disable()
                                }
                            }
                    }
                    
                    if !backTapService.isAvailable {
                        Text("Motion detection is not available on this device")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                } header: {
                    Text("Motion Detection Settings")
                } footer: {
                    Text("Detect motion to quickly add dhikr counts. Choose between shake detection, back tap detection, or both.")
                }
                
                Section("Detection Mode") {
                    Picker("Detection Mode", selection: $backTapService.detectionMode) {
                        ForEach(BackTapService.DetectionMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .onChange(of: backTapService.detectionMode) { newValue in
                        backTapService.setDetectionMode(newValue)
                    }
                    
                    switch backTapService.detectionMode {
                    case .shake:
                        Text("Detects when you shake your phone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .backTap:
                        Text("Detects when you tap the back of your phone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .both:
                        Text("Detects both shaking and back tapping")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Debug Information") {
                    Text(backTapService.debugInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if backTapService.isAvailable {
                    Section("Single Tap Action") {
                        Picker("Single Tap", selection: $backTapService.singleTapType) {
                            ForEach(DhikrType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .onChange(of: backTapService.singleTapType) { newValue in
                            backTapService.setSingleTapAction(newValue)
                        }
                    }
                    
                    Section("Double Tap Action") {
                        Picker("Double Tap", selection: $backTapService.doubleTapType) {
                            ForEach(DhikrType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .onChange(of: backTapService.doubleTapType) { newValue in
                            backTapService.setDoubleTapAction(newValue)
                        }
                    }
                    
                    Section("Triple Tap Action") {
                        Picker("Triple Tap", selection: $backTapService.tripleTapType) {
                            ForEach(DhikrType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .onChange(of: backTapService.tripleTapType) { newValue in
                            backTapService.setTripleTapAction(newValue)
                        }
                    }
                    
                    Section("Test Motion Detection") {
                        Button("Test Single Tap") {
                            backTapService.triggerSingleTap()
                        }
                        
                        Button("Test Double Tap") {
                            backTapService.triggerDoubleTap()
                        }
                        
                        Button("Test Triple Tap") {
                            backTapService.triggerTripleTap()
                        }
                    }
                }
            }
            .navigationTitle("Motion Detection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            backTapService.loadConfiguration()
        }
    }
} 