import Foundation
import CoreBluetooth
import Combine
import UIKit

class BluetoothService: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BluetoothService()
    // MARK: - Published Properties
    @Published var dhikrCount: Int = 0
    @Published var connectionStatus: String = "Initializing..."
    @Published var isConnected: Bool = false
    @Published var activeDhikrType: DhikrType = .astaghfirullah
    @Published var isScanning: Bool = false
    @Published var discoveredRings: [DiscoveredRing] = []
    @Published var savedPeripheralId: String? = UserDefaults.standard.string(forKey: "zikrPeripheralId")

    // Track if user has ever connected a ring
    private var hasEverConnectedRing: Bool {
        get { UserDefaults.standard.bool(forKey: "hasEverConnectedZikrRing") }
        set { UserDefaults.standard.set(newValue, forKey: "hasEverConnectedZikrRing") }
    }

    // MARK: - Core Bluetooth Properties
    private var centralManager: CBCentralManager?
    private let bluetoothQueue = DispatchQueue(label: "fm.mrc.dhikr.bluetooth")
    private var isBluetoothInitialized = false
    private var zikrPeripheral: CBPeripheral?
    private var tasbihCharacteristic: CBCharacteristic?
    private var discoveredMap: [UUID: CBPeripheral] = [:]
    private var retainedPeripherals: [UUID: CBPeripheral] = [:]

    // Correct UUIDs for the iQibla Zikr 1 Lite ring
    private let zikrServiceUUID = CBUUID(string: "D0FF")
    private let zikrAltServiceUUID = CBUUID(string: "FEE7") // Seen in logs for Zikr Ring Lite
    private let commandCharacteristicUUID = CBUUID(string: "D001")
    private let countCharacteristicUUID = CBUUID(string: "D002")
    private let unlockCommand = Data([0xF1])

    // MARK: - Dhikr Integration
    private let dhikrService = DhikrService.shared
    
    // Throttling properties to prevent UI freeze from rapid updates
    private var ringCount: Int = 0
    private var lastProcessedCount: Int = 0
    private var updateTimer: Timer?
    private var debounceWorkItem: DispatchWorkItem?
    private var firstValueAfterConnect: Bool = true
    private var lastDiscoveryAt: Date?

    // MARK: - Initialization
    override init() {
        super.init()
        lastProcessedCount = UserDefaults.standard.integer(forKey: "zikrLastProcessedCount")
        print("🔵 [BluetoothService] Initialized (Bluetooth not started yet)")

        // Only initialize Bluetooth if user has connected before
        if hasEverConnectedRing {
            print("🔵 [BluetoothService] User has connected before, initializing Bluetooth")
            initializeBluetooth()
        } else {
            print("🔵 [BluetoothService] First time user, waiting for manual scan")
            connectionStatus = "Ready to scan"
        }
    }

    private func initializeBluetooth() {
        guard !isBluetoothInitialized else { return }

        let restoreIdentifier = "fm.mrc.dhikr.bluetoothRestoreKey"
        let options = [CBCentralManagerOptionRestoreIdentifierKey: restoreIdentifier]
        centralManager = CBCentralManager(delegate: self, queue: bluetoothQueue, options: options)
        isBluetoothInitialized = true
        print("🔵 [BluetoothService] Bluetooth initialized with restore key: \(restoreIdentifier)")
    }

    // MARK: - Public Methods
    func startScanning() {
        // Initialize Bluetooth if not already done (first time scan)
        if !isBluetoothInitialized {
            print("🔵 [BluetoothService] First time scan, initializing Bluetooth")
            initializeBluetooth()
            // Wait for centralManagerDidUpdateState to be called
            connectionStatus = "Initializing Bluetooth..."
            return
        }

        guard let centralManager = centralManager else {
            print("❌ startScanning() called, but central manager is nil")
            return
        }

        guard centralManager.state == .poweredOn else {
            print("❌ startScanning() called, but Bluetooth is not powered on. State is: \(centralManager.state.rawValue)")
            connectionStatus = "Bluetooth not ready. Please enable it in Settings."
            return
        }

        connectionStatus = "Scanning for Zikr rings..."
        print("🔍 [BLE] Preparing scan for Zikr rings…")
        discoveredMap.removeAll()
        DispatchQueue.main.async {
            self.discoveredRings.removeAll()
            self.isScanning = true
        }
        lastDiscoveryAt = nil
        let debugAll = UserDefaults.standard.bool(forKey: "bleDebugScanAll")
        if debugAll {
            print("🧪 [BLE] Debug scan (ALL devices) for 3s…")
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self else { return }
                self.centralManager?.stopScan()
                print("🧪 [BLE] Debug scan complete. Switching to filtered Zikr scan…")
                self.centralManager?.scanForPeripherals(withServices: [self.zikrServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            }
        } else {
            print("🔎 [BLE] Scanning for Zikr rings (D0FF/FEE7 services)…")
            // First try with service filters
            centralManager.scanForPeripherals(withServices: [zikrServiceUUID, zikrAltServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            
            // Fallback: if no discoveries in 3s, scan all but still filter for Zikr only
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self else { return }
                if self.isScanning && self.lastDiscoveryAt == nil {
                    print("⚠️ [BLE] No Zikr rings found with service filter. Scanning all devices but filtering for Zikr…")
                    self.centralManager?.stopScan()
                    // Scan all devices, but we'll still filter in didDiscover to only show Zikr
                    self.centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                        if self.isScanning {
                            self.stopScanning(withMessage: self.discoveredRings.isEmpty ? "No Zikr rings found" : "Scan finished")
                        }
                    }
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            if !self.isConnected && self.isScanning {
                self.stopScanning(withMessage: "Scan finished")
            }
        }
    }

    func disconnect() {
        guard let peripheral = zikrPeripheral else { return }
        centralManager?.cancelPeripheralConnection(peripheral)
    }

    // Backwards-compatible alias used by ProfileView
    func disconnectActive() { disconnect() }

    func stopScanning(withMessage message: String? = nil) {
        centralManager?.stopScan()
        DispatchQueue.main.async {
            if let message = message { self.connectionStatus = message }
            self.isScanning = false
        }
    }

    func connectToDiscoveredRing(id: UUID) {
        guard let peripheral = discoveredMap[id] else { return }
        stopScanning()
        DispatchQueue.main.async { self.connectionStatus = "Connecting to \(peripheral.name ?? "device")..." }
        // Strongly retain and set as active before connecting to avoid API MISUSE
        zikrPeripheral = peripheral
        zikrPeripheral?.delegate = self
        retainedPeripherals[id] = peripheral
        print("🔗 [BLE] Connecting to peripheral: id=\(id.uuidString), name=\(peripheral.name ?? "Unknown")")
        let connectOpts: [String: Any] = [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionNotifyOnNotificationKey: true
        ]
        centralManager?.connect(peripheral, options: connectOpts)
    }

    // MARK: - Dhikr Integration Methods
    private func handleRingCountUpdate(_ newCount: Int) {
        // Store latest count and debounce processing for smoother UI
        self.ringCount = newCount
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.processRingCount()
        }
        debounceWorkItem = work
        bluetoothQueue.asyncAfter(deadline: .now() + 0.2, execute: work)
    }
    
    // MARK: - Throttling Logic
    private func startUpdateTimer() {
        // Debounce on notify updates; no periodic timer needed
        stopUpdateTimer()
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
        print("⏱️ Throttling timer stopped.")
    }
    
    @objc private func processRingCount() {
        let newCount = ringCount
        let lastCount = lastProcessedCount

        // First value after notifications enabled: treat as baseline only
        if firstValueAfterConnect {
            firstValueAfterConnect = false
            DispatchQueue.main.async {
                self.dhikrCount = newCount
                self.lastProcessedCount = newCount
                UserDefaults.standard.set(newCount, forKey: "zikrLastProcessedCount")
            }
            return
        }

        guard newCount != lastCount else { return }

        // Condition 1: Ring was reset to 0.
        if newCount == 0 && lastCount > 0 {
            if UserDefaults.standard.object(forKey: "autoCycleOnRingReset") as? Bool ?? true {
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
            }
            showHapticFeedback(style: .medium)
        } else if newCount > lastCount {
            // Condition 2: Ring count has increased.
            let increments = newCount - lastCount
            dhikrService.incrementDhikr(activeDhikrType, by: increments)
            // Haptic for single deliberate tap only
            if increments == 1 {
                showHapticFeedback(style: .light)
            }
        }

        // Update the published count and the last processed count
        DispatchQueue.main.async {
            self.dhikrCount = newCount
            self.lastProcessedCount = newCount
            UserDefaults.standard.set(newCount, forKey: "zikrLastProcessedCount")
        }
    }

    // MARK: - Helper Methods
    private func updateStatus(_ status: String) {
        DispatchQueue.main.async { self.connectionStatus = status }
        // Reset status message after a couple of seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.connectionStatus == status else { return }
            DispatchQueue.main.async { self.connectionStatus = "Connected and listening" }
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
            DispatchQueue.main.async { self.connectionStatus = "Bluetooth Ready" }
            print("✅ Bluetooth is powered on. Attempting fast reconnect…")
            // Try fast reconnects first
            let connected = central.retrieveConnectedPeripherals(withServices: [zikrServiceUUID, zikrAltServiceUUID])
            if let p = connected.first {
                self.zikrPeripheral = p
                self.zikrPeripheral?.delegate = self
                central.connect(p, options: nil)
            } else if let idString = UserDefaults.standard.string(forKey: "zikrPeripheralId"), let uuid = UUID(uuidString: idString) {
                let known = central.retrievePeripherals(withIdentifiers: [uuid])
                if let p = known.first {
                    self.zikrPeripheral = p
                    self.zikrPeripheral?.delegate = self
                    central.connect(p, options: nil)
                } else {
                    // Only auto-scan if user has connected before
                    if hasEverConnectedRing {
                        print("🔵 [BluetoothService] User has connected before, auto-scanning for ring")
                        startScanning()
                    } else {
                        print("🔵 [BluetoothService] First time user, waiting for manual scan")
                        DispatchQueue.main.async { self.connectionStatus = "Ready to scan" }
                    }
                }
            } else {
                // Only auto-scan if user has connected before
                if hasEverConnectedRing {
                    print("🔵 [BluetoothService] User has connected before, auto-scanning for ring")
                    startScanning()
                } else {
                    print("🔵 [BluetoothService] First time user, waiting for manual scan")
                    DispatchQueue.main.async { self.connectionStatus = "Ready to scan" }
                }
            }
        case .poweredOff:
            DispatchQueue.main.async { self.connectionStatus = "Bluetooth is Off" }
            print("❌ Bluetooth is powered off.")
            DispatchQueue.main.async { self.isConnected = false }
            stopUpdateTimer()
            firstValueAfterConnect = true
        case .unauthorized:
            DispatchQueue.main.async { self.connectionStatus = "Permission Denied" }
            print("❌ Bluetooth permission was denied by the user.")
        default:
            DispatchQueue.main.async { self.connectionStatus = "Bluetooth not ready (\(central.state.rawValue))" }
            print("⚠️ Bluetooth state is not ready: \(central.state.rawValue)")
        }
    }

    @objc func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let peripheralName = peripheral.name ?? "Unknown Device"
        lastDiscoveryAt = Date()
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map { $0.uuidString } ?? []
        var mfgHex = ""
        if let mfg = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            mfgHex = mfg.map { String(format: "%02hhx", $0) }.joined()
        }
        print("🔍 [BLE-ALL] name=\(peripheralName), id=\(peripheral.identifier.uuidString), RSSI=\(RSSI), services=\(serviceUUIDs), mfg=\(mfgHex)")

        // Identify Zikr candidates - ONLY show Zikr rings
        let isZikrByService = serviceUUIDs.contains(where: { 
            $0.caseInsensitiveCompare("D0FF") == .orderedSame || 
            $0.caseInsensitiveCompare("FEE7") == .orderedSame 
        })
        let isZikrByName = peripheral.name?.lowercased().contains("zikr") == true || 
                          peripheral.name?.lowercased().contains("iqibla") == true
        
        // ONLY add to discovered list if it's a Zikr ring
        if isZikrByService || isZikrByName {
            print("💍 [BLE-ZIKR] Found Zikr ring: name=\(peripheralName), id=\(peripheral.identifier.uuidString), RSSI=\(RSSI)")
            
            // Track only Zikr devices
            discoveredMap[peripheral.identifier] = peripheral
            let ring = DiscoveredRing(id: peripheral.identifier, name: peripheralName, rssi: RSSI.intValue)
            DispatchQueue.main.async {
                if !self.discoveredRings.contains(where: { $0.id == ring.id }) {
                    self.discoveredRings.append(ring)
                } else if let idx = self.discoveredRings.firstIndex(where: { $0.id == ring.id }) {
                    self.discoveredRings[idx] = ring
                }
            }
        } else {
            print("⏭️ [BLE] Skipping non-Zikr device: \(peripheralName)")
        }
    }

    @objc func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.connectionStatus = "Connected to \(peripheral.name ?? "device")"
            self.isConnected = true
        }
        print("✅ [BLE] Connected: name=\(peripheral.name ?? "Unknown"), id=\(peripheral.identifier.uuidString). Discovering services (all)…")
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: "zikrPeripheralId")
        DispatchQueue.main.async { self.savedPeripheralId = peripheral.identifier.uuidString }

        // Mark that user has successfully connected a ring
        hasEverConnectedRing = true
        print("🔵 [BluetoothService] First successful connection - will auto-scan on next app launch")

        firstValueAfterConnect = true
        peripheral.delegate = self
        retainedPeripherals[peripheral.identifier] = peripheral
        peripheral.discoverServices(nil)
    }

    @objc func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.connectionStatus = "Failed to connect"
            self.isConnected = false
        }
        print("❌ Failed to connect to \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "Unknown error")")
    }

    @objc func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.connectionStatus = "Disconnected"
            self.isConnected = false
            self.dhikrCount = 0
        }
        // Reset state
        stopUpdateTimer()
        ringCount = 0
        lastProcessedCount = 0
        firstValueAfterConnect = true
        activeDhikrType = .astaghfirullah
        zikrPeripheral = nil
        tasbihCharacteristic = nil
        retainedPeripherals.removeValue(forKey: peripheral.identifier)
        print("🔌 Disconnected from \(peripheral.name ?? "Unknown"). Error: \(error?.localizedDescription ?? "No error")")
    }

    // MARK: - CBPeripheralDelegate
    @objc func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error { print("❌ [BLE] Service discovery failed: \(error.localizedDescription)"); return }
        guard let services = peripheral.services, !services.isEmpty else {
            print("⚠️ [BLE] No services found on peripheral: \(peripheral.identifier.uuidString)")
            return
        }
        print("🔧 [BLE] Discovered services: \(services.map { $0.uuid.uuidString })")
        var foundZikr = false
        for service in services {
            if service.uuid == zikrServiceUUID || service.uuid == zikrAltServiceUUID { foundZikr = true }
            // Discover all characteristics so we can subscribe to notify ones even on alt service
            peripheral.discoverCharacteristics(nil, for: service)
        }
        if !foundZikr { print("⚠️ [BLE] D0FF not present; attempting to find characteristics across all services.") }
    }

    @objc func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error { print("❌ [BLE] Char discovery failed for service \(service.uuid): \(error.localizedDescription)"); return }
        guard let characteristics = service.characteristics else { return }
        print("🔑 [BLE] Service \(service.uuid) characteristics: \(characteristics.map { $0.uuid.uuidString })")

        if let commandChar = characteristics.first(where: { $0.uuid == commandCharacteristicUUID }) {
            print("✅ [BLE] Found command char; sending unlock…")
            DispatchQueue.main.async { self.connectionStatus = "Unlocking ring..." }
            peripheral.writeValue(unlockCommand, for: commandChar, type: .withResponse)
        }
        // Strictly subscribe only to D002 (count) to avoid firmware disconnects
        if let countChar = characteristics.first(where: { $0.uuid == countCharacteristicUUID }) {
            print("📡 [BLE] Subscribing to count char: \(countChar.uuid)")
            peripheral.setNotifyValue(true, for: countChar)
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
            DispatchQueue.main.async { self.connectionStatus = "Connected and listening" }
            firstValueAfterConnect = true
            startUpdateTimer() // Using debounce-based processing
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

// MARK: - Models
extension BluetoothService {
    struct DiscoveredRing: Identifiable, Equatable {
        let id: UUID
        let name: String
        let rssi: Int
    }
}