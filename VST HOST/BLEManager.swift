//
 //  ViewControler.swift
 //  VST HOST
 //
 //  Created by Théophile Dal on 16/03/2026.
 //

 import CoreBluetooth
 import SwiftUI
 import Combine

 class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
     
     @Published var message: String = ""
     @Published var isConnected: Bool = false
     @Published var vstsLibraryCharMessage: Data = Data()
     @Published var presetCharMessage: String = ""
     @Published var presetInfoCharMessage: Data = Data()
     @Published var settingListCharMessage: Data = Data()
     
     private var centralManager: CBCentralManager!
     private var peripheral: CBPeripheral!
     
     override init() {
         super.init()
         centralManager = CBCentralManager(delegate: self, queue: nil)
         message = "Starting..."
         print("Bluetooth Starting...")
     }
     
     func centralManagerDidUpdateState(_ central: CBCentralManager) {
         if central.state == .poweredOn {
             message = "Scanning for Raspberry Pi..."
             centralManager.scanForPeripherals(withServices: [BLEServer.RasberryHostServiceUUID],
                                               options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
         } else {
             message = "Bluetooth OFF - Turn it ON!"
         }
     }
     
     func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

         // We've found it so stop scan
         self.centralManager.stopScan()

         // Copy the peripheral instance
         self.peripheral = peripheral
         peripheral.delegate = self
         
         // Connect!
         self.centralManager.connect(self.peripheral, options: nil)
     }
     
     func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
         if peripheral == self.peripheral {
             message = "Connected to Raspberry Pi"
             peripheral.delegate = self
             peripheral.discoverServices([BLEServer.RasberryHostServiceUUID])
         }
     }
     
     func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
         if let services = peripheral.services {
             if services.isEmpty {
                 peripheral.discoverServices([BLEServer.RasberryHostServiceUUID])
                 return
             }
             for service in services {
                 if service.uuid == BLEServer.RasberryHostServiceUUID {
                     message = "Vst host ready \n Clic to start"
                     peripheral.discoverCharacteristics(nil, for: service)
                     return
                 }
             }
         }
     }
     
     func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
         if let characteristics = service.characteristics {
             for characteristic in characteristics {
                 if characteristic.uuid == BLEServer.RasberryPresetServiceUUID {
                     print("RasberryPresetServiceUUID found")
                     isConnected = true
                     if characteristic.properties.contains(.notify) {
                         peripheral.setNotifyValue(true, for: characteristic)
                     }
                 }
                 else if characteristic.uuid == BLEServer.RasberryListPresetsServiceUUID {
                     print("RasberryListPresetsServiceUUID found")
                     if characteristic.properties.contains(.notify) {
                         peripheral.setNotifyValue(true, for: characteristic)
                     }
                 }
                 else if characteristic.uuid == BLEServer.RasberryPresetInfoServiceUUID {
                     print("RasberryListPresetsServiceUUID found")
                     if characteristic.properties.contains(.notify) {
                         peripheral.setNotifyValue(true, for: characteristic)
                     }
                 }
                 else if characteristic.uuid == BLEServer.RasberryParamChangeServiceUUID {
                     print("RasberryParamChangeServiceUUID found")
                     if characteristic.properties.contains(.notify) {
                         peripheral.setNotifyValue(true, for: characteristic)
                     }
                 }
                 else if characteristic.uuid == BLEServer.RasberrySettingListServiceUUID {
                     print("RasberrySettingListServiceUUID found")
                     if characteristic.properties.contains(.notify) {
                         peripheral.setNotifyValue(true, for: characteristic)
                     }
                 }
                 else if characteristic.uuid == BLEServer.RasberrySettingChangeServiceUUID {
                     print("RasberrySettingChangeServiceUUID found")
                     if characteristic.properties.contains(.notify) {
                         peripheral.setNotifyValue(true, for: characteristic)
                     }
                 }
             }
         }
         self.peripheral = peripheral
     }
     
     func readPeripheral(characteristic: CBCharacteristic) {
         guard let data = characteristic.value else { return }
         
         if characteristic.uuid == BLEServer.RasberryPresetServiceUUID {
             if let msg = String(data: data, encoding: .utf8) {
                 presetCharMessage = msg
                 message = msg
             }
         }
         else if characteristic.uuid == BLEServer.RasberryListPresetsServiceUUID {
             vstsLibraryCharMessage = data
         }
         else if characteristic.uuid == BLEServer.RasberryPresetInfoServiceUUID {
             presetInfoCharMessage = data
         }
         else if characteristic.uuid == BLEServer.RasberrySettingListServiceUUID {
             settingListCharMessage = data
         }
     }

     func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
         print("New value received")
         readPeripheral(characteristic: characteristic)
     }
     
     func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
         guard peripheral == self.peripheral else { return }

         // Vérifie si TON service est impacté
         let isTargetServiceInvalidated = invalidatedServices.contains {
             $0.uuid == BLEServer.RasberryHostServiceUUID
         }

         if isTargetServiceInvalidated {
             peripheral.discoverServices([BLEServer.RasberryHostServiceUUID])
             message = "Vst host disconnected"
             isConnected = false
         }
     }
          
     func writeCharacteristic(uuid: CBUUID, value: String) {
         
         guard let services = peripheral.services else { return }
         
         for service in services {
             if let characteristics = service.characteristics {
                 for characteristic in characteristics {
                     
                     if characteristic.uuid == uuid {
                         
                         guard characteristic.properties.contains(.write) ||
                               characteristic.properties.contains(.writeWithoutResponse) else {
                             return
                         }
                         
                         let data = value.data(using: .utf8)!
                         
                         let type: CBCharacteristicWriteType =
                             characteristic.properties.contains(.write)
                             ? .withResponse
                             : .withoutResponse
                         
                         peripheral.writeValue(data, for: characteristic, type: type)
                         
                         print("Writing: \(value)")
                         return
                     }
                 }
             }
         }
     }
 }

