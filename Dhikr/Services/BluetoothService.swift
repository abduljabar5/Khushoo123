import Foundation
import CoreBluetooth
import Combine
import UIKit

class BluetoothService: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // MARK: - Published Properties
    @Published var dhikrCount: Int = 0
    @Published var connectionStatus: String = "Initializing..."
    @Published var isConnected: Bool = false
    @Published var activeDhikrType: DhikrType = .astaghfirullah

    // MARK: - Core Bluetooth Properties
    private var centralManager: CBCentralManager!
    private var zikrPeripheral: CBPeripheral?
    private var tasbihCharacteristic: CBCharacteristic?

    // Correct UUIDs for the iQibla Zikr 1 Lite ring
    private let zikrServiceUUID = CBUUID(string: "D0FF")
    private let commandCharacteristicUUID = CBUUID(string: "D001")
    private let countCharacteristicUUID = CBUUID(string: "D002")
    private let unlockCommand = Data([0xF1])

    // MARK: - Dhikr Integration
    private let dhikrService = DhikrService.shared
    
    // Throttling properties to prevent UI freeze from rapid updates
    private var ringCount: Int = 0
    private var lastProcessedCount: Int = 0
    private var updateTimer: Timer?

    // MARK: - Initialization
    override init() {
        super.init()
        let restoreIdentifier = "fm.mrc.dhikr.bluetoothRestoreKey"
        let options = [CBCentralManagerOptionRestoreIdentifierKey: restoreIdentifier]
        centralManager = CBCentralManager(delegate: self, queue: nil, options: options)
        print("🔵 [BluetoothService] Initialized with restore key: \(restoreIdentifier)")
    }

    // MARK: - Public Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("❌ startScanning() called, but Bluetooth is not powered on. State is: \(centralManager.state.rawValue)")
            connectionStatus = "Bluetooth not ready. Please enable it in Settings."
            return
        }

        connectionStatus = "Scanning..."
        print("🔍 Starting scan...")
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if !self.isConnected && self.connectionStatus == "Scanning..." {
                self.centralManager.stopScan()
                self.connectionStatus = "Scan timed out. Try again."
                print("⏰ Scan timed out.")
            }
        }
    }

    func disconnect() {
        guard let peripheral = zikrPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    // MARK: - Dhikr Integration Methods
    private func handleRingCountUpdate(_ newCount: Int) {
        // Just store the latest count. The timer will handle processing.
        self.ringCount = newCount
    }
    
    // MARK: - Throttling Logic
    private func startUpdateTimer() {
        stopUpdateTimer() // Invalidate any existing timer
        // Reduced frequency to improve performance - once per second instead of 4 times
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .background).async {
                self?.processRingCount()
            }
        }
        print("⏱️ Throttling timer started.")
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
        print("⏱️ Throttling timer stopped.")
    }
    
    @objc private func processRingCount() {
        // This now runs on background thread for better performance
        guard ringCount != lastProcessedCount else { return }

        let newCount = ringCount
        let lastCount = lastProcessedCount

        print("⚙️ [Throttled Update] Processing count. Current: \(newCount), Last Processed: \(lastCount)")

        // Condition 1: Ring was reset to 0.
        if newCount == 0 && lastCount > 0 {
            switch activeDhikrType {
            case .astaghfirullah:
                activeDhikrType = .alhamdulillah
                updateStatus("Switched to Alhamdulillah")
            case .alhamdulillah:
                activeDhikrType = .subhanAllah
                updateStatus("Switched to SubhanAllah")
            case .subhanAllah:
                activeDhikrType = .astaghfirullah
                updateStatus("Switched to Astaghfirullah")
            default:
                activeDhikrType = .astaghfirullah
                updateStatus("Switched to Astaghfirullah")
            }
            print("💍 Ring reset detected. Switched active Dhikr to: \(activeDhikrType.rawValue)")
            showHapticFeedback(style: .medium)
        }
        // Condition 2: Ring count has increased.
        else if newCount > lastCount {
            let increments = newCount - lastCount
            print("➕ Ring count increased by \(increments). Adding to \(activeDhikrType.rawValue).")
            for _ in 0..<increments {
                dhikrService.incrementDhikr(activeDhikrType)
            }
            // Only provide haptics for user-initiated taps, not rapid holds.
            if increments < 5 { // Heuristic: many increments at once is a hold.
                showHapticFeedback(style: .light)
            }
        }

        // Update the published count and the last processed count on main thread
        DispatchQueue.main.async {
            self.dhikrCount = newCount
            self.lastProcessedCount = newCount
        }
    }

    // MARK: - Helper Methods
    private func updateStatus(_ status: String) {
        connectionStatus = status
        // Reset status message after a couple of seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.connectionStatus == status else { return }
            self.connectionStatus = "Connected and listening"
        }
    }

    private func showHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }

    // MARK: - CBCentralManagerDelegate
    @objc func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("--- Bluetooth Status Updated ---")
        
        switch central.state {
        case .poweredOn:
            connectionStatus = "Bluetooth Ready"
            print("✅ Bluetooth is powered on. Triggering initial scan.")
            startScanning()
        case .poweredOff:
            connectionStatus = "Bluetooth is Off"
            print("❌ Bluetooth is powered off.")
            isConnected = false
            stopUpdateTimer()
        case .unauthorized:
            connectionStatus = "Permission Denied"
            print("❌ Bluetooth permission was denied by the user.")
        default:
            connectionStatus = "Bluetooth not ready (\(central.state.rawValue))"
            print("⚠️ Bluetooth state is not ready: \(central.state.rawValue)")
        }
    }

    @objc func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let peripheralName = peripheral.name ?? "Unknown Device"
        print("🟢 Discovered peripheral: \(peripheralName) | RSSI: \(RSSI)")
        
        if let name = peripheral.name, name.lowercased().contains("zikr") {
            print("✨ Found a Zikr ring: \(name)")
            self.zikrPeripheral = peripheral
            self.zikrPeripheral?.delegate = self
            
            print("🛑 Stopping scan.")
            centralManager.stopScan()
            
            connectionStatus = "Connecting to \(name)..."
            print("🔗 Connecting to \(name)...")
            centralManager.connect(peripheral, options: nil)
        }
    }

    @objc func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionStatus = "Connected to \(peripheral.name ?? "device")"
        isConnected = true
        print("✅ Successfully connected to \(peripheral.name ?? "Unknown")! Discovering services...")
        peripheral.discoverServices([zikrServiceUUID])
    }

    @objc func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Failed to connect"
        isConnected = false
        print("❌ Failed to connect to \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "Unknown error")")
    }

    @objc func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Disconnected"
        isConnected = false
        dhikrCount = 0
        // Reset state
        stopUpdateTimer()
        ringCount = 0
        lastProcessedCount = 0
        activeDhikrType = .astaghfirullah
        zikrPeripheral = nil
        tasbihCharacteristic = nil
        print("🔌 Disconnected from \(peripheral.name ?? "Unknown"). Error: \(error?.localizedDescription ?? "No error")")
    }

    // MARK: - CBPeripheralDelegate
    @objc func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error { print("❌ Service discovery failed: \(error.localizedDescription)"); return }
        guard let services = peripheral.services else { return }

        for service in services where service.uuid == zikrServiceUUID {
            print("✅ Found Zikr service (\(service.uuid)). Discovering characteristics...")
            peripheral.discoverCharacteristics([commandCharacteristicUUID, countCharacteristicUUID], for: service)
        }
    }

    @objc func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error { print("❌ Characteristic discovery failed: \(error.localizedDescription)"); return }
        guard let characteristics = service.characteristics else { return }
        
        print("🔑 Found \(characteristics.count) characteristics for service \(service.uuid).")
        
        if let commandChar = characteristics.first(where: { $0.uuid == commandCharacteristicUUID }) {
            print("✅ Found command characteristic. Writing unlock command...")
            connectionStatus = "Unlocking ring..."
            peripheral.writeValue(unlockCommand, for: commandChar, type: .withResponse)
        } else {
            print("❌ Could not find the command characteristic needed to unlock the ring.")
        }
    }
    
    @objc func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Failed to write unlock command: \(error.localizedDescription)")
            return
        }
        
        if characteristic.uuid == commandCharacteristicUUID {
            print("✅ Unlock successful. Subscribing to notifications...")
            if let service = characteristic.service, let notifyChar = service.characteristics?.first(where: { $0.uuid == countCharacteristicUUID }) {
                peripheral.setNotifyValue(true, for: notifyChar)
            }
        }
    }

    @objc func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error { print("❌ Failed to update value: \(error.localizedDescription)"); return }
        guard characteristic.uuid == countCharacteristicUUID, let data = characteristic.value else { return }

        guard let statusString = String(data: data, encoding: .ascii) else {
            print("⚠️ Received notification with non-ASCII data.")
            return
        }
        
        let components = statusString.components(separatedBy: ",")
        
        if components.count > 1, let count = Int(components[1]) {
            // Use main queue to prevent race conditions on the ringCount property
            DispatchQueue.main.async {
                self.handleRingCountUpdate(count)
            }
        }
    }
    
    @objc func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Failed to update notification state: \(error.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            print("✅ Notifications enabled for characteristic: \(characteristic.uuid)")
            connectionStatus = "Connected and listening"
            startUpdateTimer() // Start processing updates
        } else {
            print("⚠️ Notifications disabled for characteristic: \(characteristic.uuid)")
            stopUpdateTimer() // Stop processing updates
        }
    }

    // MARK: - State Restoration
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        print("🔵 [BluetoothService] Will restore state...")
        
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            print("   - Found \(peripherals.count) peripheral(s) to restore.")
            for peripheral in peripherals {
                // Check if this is our Zikr ring
                if peripheral.name?.lowercased().contains("zikr") == true || peripheral.identifier == zikrPeripheral?.identifier {
                    print("   - Restoring: \(peripheral.name ?? "Unknown Peripheral")")
                    zikrPeripheral = peripheral
                    zikrPeripheral?.delegate = self
                    
                    // The connection should be restored by the system, but we update our UI state
                    DispatchQueue.main.async {
                        if peripheral.state == .connected {
                            self.isConnected = true
                            self.connectionStatus = "Connected (Restored)"
                            // Re-start the throttling timer to process updates
                            self.startUpdateTimer()
                        } else {
                            self.isConnected = false
                            self.connectionStatus = "Disconnected"
                        }
                    }
                    // No need to call connect() here, the system handles it.
                    return // Exit after finding our peripheral
                }
            }
        }
    }
}

// MARK: - Data Extension
extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
} 