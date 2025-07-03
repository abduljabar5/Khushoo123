import SwiftUI

struct BackTapTestView: View {
    @ObservedObject var backTapService = BackTapService.shared
    @ObservedObject var dhikrService = DhikrService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    statusSection
                    configurationSection
                    testButtonsSection
                    currentCountsSection
                    tipsSection
                }
                .padding()
            }
            .navigationTitle("Back Tap Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .backTapDhikrAdded)) { notification in
            // This will trigger a UI update when back tap adds dhikr
            print("Back tap dhikr added: \(notification.object ?? "unknown")")
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 16) {
            Text("Back Tap Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Circle()
                    .fill(backTapService.isEnabled ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(backTapService.isEnabled ? "Enabled" : "Disabled")
                    .font(.subheadline)
            }
            
            if !backTapService.isAvailable {
                Text("⚠️ Motion detection not available on this device")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var configurationSection: some View {
        VStack(spacing: 16) {
            Text("Current Configuration")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Single Tap:")
                    Spacer()
                    Picker("Single Tap", selection: $backTapService.singleTapType) {
                        ForEach(DhikrType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: backTapService.singleTapType) { newValue in
                        backTapService.setSingleTapAction(newValue)
                    }
                }
                HStack {
                    Text("Double Tap:")
                    Spacer()
                    Picker("Double Tap", selection: $backTapService.doubleTapType) {
                        ForEach(DhikrType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: backTapService.doubleTapType) { newValue in
                        backTapService.setDoubleTapAction(newValue)
                    }
                }
                HStack {
                    Text("Triple Tap:")
                    Spacer()
                    Picker("Triple Tap", selection: $backTapService.tripleTapType) {
                        ForEach(DhikrType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: backTapService.tripleTapType) { newValue in
                        backTapService.setTripleTapAction(newValue)
                    }
                }
                HStack {
                    Text("Debug Logging:")
                    Spacer()
                    Button(action: {
                        backTapService.toggleDebugLogging()
                    }) {
                        Text(backTapService.debugLoggingEnabled ? "ON" : "OFF")
                            .fontWeight(.medium)
                            .foregroundColor(backTapService.debugLoggingEnabled ? .green : .red)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var testButtonsSection: some View {
        VStack(spacing: 16) {
            Text("Test Back Tap")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Button(action: {
                    backTapService.triggerSingleTap()
                }) {
                    HStack {
                        Image(systemName: "hand.tap")
                        Text("Test Single Tap")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!backTapService.isEnabled)
                
                Button(action: {
                    backTapService.triggerDoubleTap()
                }) {
                    HStack {
                        Image(systemName: "hand.tap.fill")
                        Text("Test Double Tap")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!backTapService.isEnabled)
                
                Button(action: {
                    backTapService.triggerTripleTap()
                }) {
                    HStack {
                        Image(systemName: "hand.tap.fill")
                        Text("Test Triple Tap")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!backTapService.isEnabled)
            }
        }
    }
    
    private struct DhikrCountRow: View {
        let type: DhikrType
        let count: Int
        var body: some View {
            HStack {
                Text(type.rawValue)
                Spacer()
                Text("\(count)")
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
        }
    }
    
    private var currentCountsSection: some View {
        VStack(spacing: 16) {
            Text("Current Dhikr Counts")
                .font(.headline)
                .fontWeight(.semibold)
            VStack(spacing: 8) {
                ForEach(Array(DhikrType.allCases), id: \.self) { type in
                    DhikrCountRow(type: type, count: dhikrService.dhikrCount.count(for: type))
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var tipsSection: some View {
        VStack(spacing: 8) {
            Text("💡 Tips for Better Detection:")
                .font(.caption)
                .fontWeight(.semibold)
            
            Text("• Hold your phone firmly")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("• Tap the back with moderate force")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("• Wait 0.8 seconds between tap sequences")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
} 