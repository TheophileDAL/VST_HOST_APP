//
//  ParticlePeripheral.swift
//  VST HOST
//
//  Created by Théophile Dal on 16/03/2026.
//


import UIKit
import CoreBluetooth

class BLEServer: NSObject {

    public static let RasberryHostServiceUUID  = CBUUID.init(string: "d98c8810-876b-4516-988c-28c7384a33cc")
    public static let RasberryListPresetsServiceUUID = CBUUID.init(string: "d98c8811-876b-4516-988c-28c7384a33cc")
    public static let RasberryPresetServiceUUID = CBUUID.init(string: "d98c8812-876b-4516-988c-28c7384a33cc")
    public static let RasberryPresetInfoServiceUUID = CBUUID.init(string: "d98c8813-876b-4516-988c-28c7384a33cc")
    public static let RasberryParamChangeServiceUUID = CBUUID.init(string: "d98c8814-876b-4516-988c-28c7384a33cc")
    public static let RasberrySettingListServiceUUID = CBUUID.init(string: "d98c8815-876b-4516-988c-28c7384a33cc")
    public static let RasberrySettingChangeServiceUUID = CBUUID.init(string: "d98c8816-876b-4516-988c-28c7384a33cc")

}
