//
//  RaspberryHost.swift
//  VST HOST
//
//  Created by Théophile Dal on 19/03/2026.
//

import SwiftUI
import Combine

struct Parameter: Codable, Hashable{
    let name: String
    let id: Int
    let unit: String
    var value: Double
    let min: Double
    let max: Double
}

struct Plugin: Codable, Hashable{
    let name: String
    let id: Int
    let param_count: Int
    var parameters: [Parameter]
}

struct Preset: Codable{
    let name: String
    let plugin_count: Int
    var plugins: [Plugin]
}

struct FaderParameter: Codable, Hashable{
    var id : Int
    var name: String
    var pluginId: Int
    var parameterId: Int
    var value: Double
}

struct VST: Codable, Hashable{
    var name: String
    var list: [VST]?
}

struct VSTstate: Codable, Hashable{
    var name: String
    var stream: Int
    var host: Int
    var preset: [Int]
    var settings: [Int]
}

struct KnobParamPair {
    var pluginId: Int?
    var paramId: Int?
    var knobId: Int?
}

struct Setting: Codable, Hashable {
    var name: String
    var value: Double?
    var selected: String?
    var list: [Setting]?
}

class RaspberryHost: NSObject, ObservableObject {
    @Published var VSTList: [VST] = []
    @Published var presetActual: Preset = Preset(name: "", plugin_count: 0, plugins: [])
    @Published var state: VSTstate = VSTstate(name: "load setup", stream : 0, host: -1, preset: [], settings: [])
    @Published var loading_preset: String = ""
    @Published var faderParameters: [FaderParameter] = []
    @Published var NUM_OF_FADERS: Int = 4
    @Published var param_to_knob = KnobParamPair()
    @Published var settings: [Setting] = []

    var ble_manager: BLEManager
    private var cancellables = Set<AnyCancellable>()
    var jsonData: Data = Data()
    var jsonData2: Data = Data()
    let test: Bool
    
    init(ble_manager: BLEManager, test : Bool) {
        self.ble_manager = ble_manager
        self.test = test
        
        super.init()
        
        if (self.test == false){
            ble_manager.$vstsLibraryCharMessage
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.setPresets()
                }
                .store(in: &cancellables)
            
            ble_manager.$isConnected
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.reinitialize()
                }
                .store(in: &cancellables)
            
            ble_manager.$presetInfoCharMessage
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.setParameters()
                }
                .store(in: &cancellables)
            
            ble_manager.$presetCharMessage
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.getPreset()
                }
                .store(in: &cancellables)
            
            ble_manager.$settingListCharMessage
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.setSettings()
                }
                .store(in: &cancellables)
        }
        else {
            setPresets()
            setParameters()
        }
        
    }
    
    func reinitialize(){
        if (ble_manager.isConnected == false){
            ble_manager.vstsLibraryCharMessage = Data()
            ble_manager.presetInfoCharMessage = Data()
            ble_manager.presetCharMessage = ""
            VSTList = []
            faderParameters = []
            presetActual = Preset(name: "", plugin_count: 0, plugins: [])
            state = VSTstate(name: "load setup", stream: 0, host: -1, preset: [], settings: [])
        }
    }

    func setPresets() {
        if (self.test == true){
            let vst1 = VST(name: "Carla", list: [VST(name: "Bank1", list: [VST(name:"Piano1"), VST(name:"Piano2"), VST(name:"Pad1"), VST(name:"Clavecin1")]), VST(name: "Bank2", list: [VST(name:"Synthe1"), VST(name:"Synthe2"), VST(name:"Synthe3")])])
            let vst2 = VST(name: "Arturia", list: [VST(name:"Pad1"), VST(name:"Clavecin1"), VST(name:"Synthe1"), VST(name:"Synthe2"), VST(name:"Synthe3"), VST(name:"Guitar1"), VST(name:"Guitare2")])
            let vst3 = VST(name: "Pianoteq", list: [VST(name:"Piano1"), VST(name:"Piano2"), VST(name:"Piano3"), VST(name:"Piano4"), VST(name:"Piano5"), VST(name:"Piano1"), VST(name:"Piano6")])
            let vst4 = VST(name: "Kontakt", list: [VST(name:"Piano1"), VST(name:"String1"), VST(name:"String2"), VST(name:"String3"), VST(name:"Drums1"), VST(name:"Drums2"), VST(name:"Drums3")])
            let vst5 = VST(name: "AmpliTube", list: [VST(name:"Amp1"), VST(name:"Amp2"), VST(name:"Amp3"), VST(name:"Amp4"), VST(name:"Amp5"), VST(name:"Amp6"), VST(name:"Amp7")])
            let vst6 = VST(name: "Pedals", list: [VST(name:"Pedal1"), VST(name:"Pedal2"), VST(name:"Pedal3"), VST(name:"Pedal4"), VST(name:"Pedal5"), VST(name:"Pedal16"), VST(name:"Pedal7")])
            VSTList = [VST(name: "Midi", list: [vst1, vst2, vst3, vst4]), VST(name: "Audio", list: [vst5, vst6])]
        }
        else if (!ble_manager.vstsLibraryCharMessage.isEmpty){
            let data = ble_manager.vstsLibraryCharMessage
            if (!data.isEmpty){
                let msg = String(data: data, encoding: .utf8)
                print(jsonData)
                if (msg == "end of transmission"){
                    let decoder = JSONDecoder()
                    do {
                        let parsedPreset = try decoder.decode([VST].self, from: jsonData)
                        self.VSTList = parsedPreset
                        
                        print(self.VSTList)
                        if (state.name == "load host" || state.name == "install host"){
                            if let _ = self.VSTList[state.stream].list?[state.host].list {
                                state.name = "host loaded"
                            }
                            else{
                                state.name = "host not installed"
                            }
                        }
                        else if (state.name == "load preset"){
                            state.name = "preset loaded"
                        }
                    } catch {
                        print("[RaspberryHost] Failed to decode preset JSON: \(error)")
                    }
                    jsonData = Data()
                }
                else{
                    jsonData.append(ble_manager.vstsLibraryCharMessage)
                    print(ble_manager.vstsLibraryCharMessage)
                }
            }
        }
    }
    
    func setSettings() {
        if (!ble_manager.settingListCharMessage.isEmpty){
            let data = ble_manager.settingListCharMessage
            if (!data.isEmpty){
                let msg = String(data: data, encoding: .utf8)
                print(msg!)
                print(jsonData2)
                if (msg == "end of transmission"){
                    let decoder = JSONDecoder()
                    do {
                        let parsedPreset = try decoder.decode([Setting].self, from: jsonData2)
                        self.settings = parsedPreset
                        print(self.settings)

                    } catch {
                        print("[RaspberryHost Settings] Failed to decode preset JSON: \(error)")
                    }
                    jsonData2 = Data()
                }
                else{
                    jsonData2.append(ble_manager.settingListCharMessage)
                    print(ble_manager.settingListCharMessage)
                }
            }
        }
    }
        
    func setFaderParameters(){
        faderParameters = []
        var id : Int = 0
        for plugin in presetActual.plugins{
            for param in plugin.parameters{
                faderParameters.append(FaderParameter(id: id, name: param.name ,pluginId: plugin.id, parameterId: param.id, value: param.value))
                id = id + 1
                if faderParameters.count >= NUM_OF_FADERS{break}
            }
            if faderParameters.count >= NUM_OF_FADERS{break}
        }
    }
    
    func changeFaderParameters(){
        if let paramId = param_to_knob.paramId,
            let knobId = param_to_knob.knobId,
            let pluginId = param_to_knob.pluginId{
            faderParameters[knobId].name = presetActual.plugins[pluginId].parameters[paramId].name
            faderParameters[knobId].pluginId = pluginId
            faderParameters[knobId].parameterId = presetActual.plugins[pluginId].parameters[paramId].id
            faderParameters[knobId].value = presetActual.plugins[pluginId].parameters[paramId].value
            param_to_knob = KnobParamPair()
        }
    }
        
    func setParameters(){
        if (self.test == true){
            let parameters = [
                Parameter(name: "Volume", id: 0, unit: "dB", value: 50, min: 0, max: 100),
                Parameter(name: "Reverb", id: 1, unit: "%", value: 25, min: 0, max: 100),
                Parameter(name: "Attack", id: 2, unit: "ms", value: 0.25, min: 0.1, max: 10),
                Parameter(name: "Decay", id: 3, unit: "ms", value: 20, min: 10, max: 100),
                Parameter(name: "Release", id: 4, unit: "ms", value: 100, min: 0, max: 500)]
            
            let plugin = Plugin(name: "Piano", id: 0, param_count: 5, parameters: parameters)
            self.presetActual = Preset(name: "Piano1", plugin_count: 1, plugins: [plugin])
            setFaderParameters()
        }
        else {
            let data = ble_manager.presetInfoCharMessage
            if (!data.isEmpty){
                let msg = String(data: data, encoding: .utf8)
                
                if (msg == "end of transmission"){
                    let decoder = JSONDecoder()
                    do {
                        let parsedPreset = try decoder.decode(Preset.self, from: jsonData)
                        self.presetActual = parsedPreset
                        setFaderParameters()
                        print(self.presetActual)
                    } catch {
                        print("[RaspberryHost] Failed to decode preset JSON: \(error)")
                    }
                    jsonData = Data()
                }
                else{
                    jsonData.append(ble_manager.presetInfoCharMessage)
                    print(ble_manager.presetInfoCharMessage)
                }
            }
        }
    }
    
    func getPreset() {
        if (!ble_manager.presetCharMessage.isEmpty){
            if let value = Int(ble_manager.presetCharMessage) {
                self.state.preset = [value]
            } else {
                self.state.preset = [0]
            }
        }
    }
    
    func setPreset(command: String){
        if (self.test == false){
            ble_manager.writeCharacteristic(uuid: BLEServer.RasberryPresetServiceUUID, value: command)
            faderParameters = []
            presetActual = Preset(name: "", plugin_count: 0, plugins: [])
        }
    }
    
    func setVST(){
        if (self.test == false){
            ble_manager.message = "loading VSTs"
            
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(self.state)
                if let jsonString = String(data: data, encoding: .utf8) {
                    ble_manager.writeCharacteristic(uuid: BLEServer.RasberryPresetServiceUUID, value: jsonString)
                } else {
                    print("[RaspberryHost] Failed to convert encoded parameter to UTF-8 string")
                }
            } catch {
                print("[RaspberryHost] Failed to encode faderParameter: \(error)")
            }
            
            if (self.state.name == "load preset"){
                var parameters: [Parameter] = []
                var value: Double
                for i in 0...NUM_OF_FADERS-1{
                    if state.stream == 0{
                        value = Double(i)*0.2
                    }
                    else{
                        value = 0.0
                    }
                    parameters.append(Parameter(name: "Animation", id: i, unit: "%", value: value, min: 0, max: 1))
                }
                let plugin = Plugin(name: "Animation", id: 0, param_count: NUM_OF_FADERS, parameters: parameters)
                self.presetActual = Preset(name: "Animation", plugin_count: 1, plugins: [plugin])
                setFaderParameters()
            }
            else if (self.state.name == "load host"){
                faderParameters = []
                presetActual = Preset(name: "", plugin_count: 0, plugins: [])
            }
        }
    }
    
    func setParameter(param : FaderParameter){
        if (self.test == false){
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(param)
                if let jsonString = String(data: data, encoding: .utf8) {
                    ble_manager.writeCharacteristic(uuid: BLEServer.RasberryParamChangeServiceUUID, value: jsonString)
                } else {
                    print("[RaspberryHost] Failed to convert encoded parameter to UTF-8 string")
                }
            } catch {
                print("[RaspberryHost] Failed to encode faderParameter: \(error)")
            }
        }
    }
}
