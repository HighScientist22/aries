//
//  OutputDevicePicker.swift
//  Aries
//

import SwiftUI

struct OutputDevicePicker: View {
    @ObservedObject var engine: AudioEngine
    @State private var devices: [AudioOutputDevice] = []
    @State private var selectedID: UInt32 = 0

    var body: some View {
        Menu {
            ForEach(devices) { device in
                Button {
                    select(device)
                } label: {
                    HStack {
                        Text(device.name)
                        if device.isDefault {
                            Text("System Default")
                        }
                        if selectedID == device.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label(currentName, systemImage: "hifispeaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .onAppear(perform: reload)
    }

    private var currentName: String {
        devices.first(where: { $0.id == selectedID })?.name
            ?? devices.first(where: \.isDefault)?.name
            ?? "Output"
    }

    private func reload() {
        devices = AudioOutputDevices.list()
        selectedID = UInt32(UserDefaults.standard.integer(forKey: "selectedOutputDeviceID"))
        if selectedID == 0, let defaultDevice = devices.first(where: \.isDefault) {
            selectedID = defaultDevice.id
        }
    }

    private func select(_ device: AudioOutputDevice) {
        if engine.setOutputDevice(device.id) {
            selectedID = device.id
            UserDefaults.standard.set(Int(device.id), forKey: "selectedOutputDeviceID")
        }
    }
}
