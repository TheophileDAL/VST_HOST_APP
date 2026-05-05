//
 //  ContentView.swift
 //  VST HOST
 //
 //  Created by Théophile Dal on 16/03/2026.
 //

 /*import SwiftUI

 struct ContentView: View {

     var body: some View {
         BLEViewControllerWrapper()
             .edgesIgnoringSafeArea(.all)
     }
 }*/

import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: UIFont
    let width: CGFloat
    
    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var task: DispatchWorkItem? = nil
    
    private let speed: CGFloat = 30
    private let pauseDuration: Double = 1.5
    
    var body: some View {
        GeometryReader { _ in
            Text(text)
                .font(Font(font))
                .fixedSize()
                .offset(x: offset)
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear {
                            textWidth = geo.size.width
                        }
                    }
                )
        }
        .frame(height: font.lineHeight)
        .clipped()
        .onAppear {
            if textWidth > width { startBouncing() }
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startBouncing() {
        let travel = textWidth - width
        guard travel > 0 else { return }
        let duration = Double(travel / speed)
        schedule(after: pauseDuration) { bounce(travel: travel, duration: duration) }
    }
    
    private func bounce(travel: CGFloat, duration: Double) {
        withAnimation(.linear(duration: duration)) { offset = -travel }
        schedule(after: duration + pauseDuration) {
            withAnimation(.linear(duration: duration)) { offset = 0 }
            schedule(after: duration + pauseDuration) { bounce(travel: travel, duration: duration) }
        }
    }
    
    private func schedule(after delay: Double, block: @escaping () -> Void) {
        let item = DispatchWorkItem(block: block)
        task = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
    
    private func stopAnimation() {
        task?.cancel()
        task = nil
        offset = 0
    }
}

struct PresetsView: View {
    
    @Binding var vst_list: [VST]
    @ObservedObject var host: RaspberryHost
    var proxy: ScrollViewProxy
    let file_number : Int
    
    @State private var visiblePresets : [Bool] = []
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(vst_list.indices, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.85), lineWidth: 2)
                            )
                            .frame(width: 130)
                            .opacity(
                                (host.state.preset.indices.contains(file_number) &&
                                 host.state.preset[file_number] == index) ? 1 : 0.2
                            )

                        MarqueeText(
                            text: vst_list[index].name,
                            font: UIFont(name: "DS-Digital", size: 25) ?? UIFont.systemFont(ofSize: 25),
                            width: 118
                        )
                        .foregroundColor(Color.white.opacity(0.85))
                        .padding(.vertical, 2)
                        .frame(width: 118)
                        .clipped()
                    }
                    .opacity(index < visiblePresets.count && visiblePresets[index] ? 1 : 0)
                    .onTapGesture {
                        host.state.preset[file_number] = index
                        for index in (file_number+1)..<host.state.preset.count {
                            host.state.preset[index] = -1
                        }
                        if vst_list[index].list == nil {
                            host.state.name = "load preset"
                            host.loading_preset = vst_list[index].name
                            host.setVST()
                        }
                    }
                }
            }
        }
        .id(file_number)
        .onAppear {
            host.state.preset.append(-1)
            scrollAndDeploy(proxy: proxy)
        }
        .onDisappear {
            if !host.state.preset.isEmpty {
                host.state.preset.removeLast()
            }
        }
        .onChange(of: vst_list){
            scrollAndDeploy(proxy: proxy)
        }
        .onChange(of: host.state.name){
            scrollToTheEnd(proxy: proxy)
        }
        
        if host.state.preset.indices.contains(file_number),
           host.state.preset[file_number] != -1,
           let list = vst_list[host.state.preset[file_number]].list,
           !list.isEmpty {

            PresetsView(
                vst_list: Binding(
                    get: {
                        if host.state.preset.indices.contains(file_number),
                           host.state.preset[file_number] != -1,
                           let list = vst_list[host.state.preset[file_number]].list,
                           !list.isEmpty {
                            vst_list[host.state.preset[file_number]].list!
                        }
                        else{
                            []
                        }
                    },
                    set: { newValue in
                        vst_list[host.state.preset[file_number]].list = newValue
                    }
                ),
                host: host,
                proxy: proxy,
                file_number: file_number + 1
            )
        }
    }
    
    func scrollToTheEnd(proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.5)) {
            proxy.scrollTo(file_number, anchor: .trailing)
        }
    }
    
    func scrollAndDeploy(proxy: ScrollViewProxy){
        visiblePresets = Array(repeating: false, count: vst_list.count)
        scrollToTheEnd(proxy: proxy)
        Task {
            for i in visiblePresets.indices {
                try? await Task.sleep(for: .milliseconds(2000/visiblePresets.count))
                withAnimation() {
                    visiblePresets[i] = true
                }
            }
        }
    }
}

 struct LCDView: View {
     
     @Binding var ble_message: String
     @Binding var ble_state: Bool
     @ObservedObject var host: RaspberryHost
     
     @State private var isVisible = true
     @State private var visiblePresets : [Bool] = []
     
     func startAnimation() {
         if (ble_message != "loading VSTs"){
             isVisible.toggle()
         }
     }

     var body: some View {
             
         GeometryReader { geo in
             HStack {
                 ZStack {
                     // Fond LCD
                     RoundedRectangle(cornerRadius: 5)
                         .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                         .overlay(
                             RoundedRectangle(cornerRadius: 5)
                                 .stroke(Color.black, lineWidth: 20)
                         )
                     
                     if host.VSTList.isEmpty && host.test == false  {
                         VStack{
                             Text(ble_message).font(.custom("DS-Digital", size: 40))
                                 .foregroundColor(Color(red: 1, green: 0.4, blue: 0.8))
                                 .padding(.all, 10)
                                 .opacity(isVisible ? 1.0 : 0.0)
                                 .onAppear {
                                     withAnimation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever(autoreverses: true)
                                     ) {
                                         startAnimation()
                                     }
                                 }
                             if (ble_message == "loading VSTs"){
                                 Chargement(width: 20, height: 30)
                             }
                         }
                         .contentShape(Rectangle()).onTapGesture{
                             if (ble_state) {
                                 host.setVST()
                             }
                         }
                     }
                     else{
                         HStack(spacing: 10) {
                             ScrollViewReader{ proxy in
                                 ScrollView(.horizontal, showsIndicators: false){
                                     HStack{
                                         ScrollView {
                                             VStack(alignment: .leading, spacing: 8) {
                                                 ForEach(host.VSTList.indices, id: \.self) { index in
                                                     ZStack{
                                                         RoundedRectangle(cornerRadius: 4)
                                                             .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                                                             .overlay(
                                                                RoundedRectangle(cornerRadius: 6)
                                                                    .stroke(Color.white.opacity(0.85), lineWidth: 2)
                                                             )
                                                             .frame(width: 130)
                                                             .opacity(host.state.stream == index ? 1 : 0.2)
                                                         Text(host.VSTList[index].name)
                                                             .font(.custom("DS-Digital", size: 25))
                                                             .foregroundColor(Color.white.opacity(0.85))
                                                             .padding(.vertical,2)
                                                     }.onTapGesture{
                                                         host.state.name = "stream loaded"
                                                         host.state.stream = index
                                                         host.state.host = -1
                                                         host.state.preset = Array(
                                                             repeating: -1,
                                                             count: host.state.preset.count
                                                         )
                                                         if (host.state.stream == 0){
                                                             host.NUM_OF_FADERS = 4
                                                         }
                                                         else{
                                                             host.NUM_OF_FADERS = 8
                                                         }
                                                         host.faderParameters = []
                                                     }
                                                 }
                                             }
                                         }.id("vst streams")
                                         ScrollView {
                                             VStack(alignment: .leading, spacing: 8) {
                                                 ForEach(host.VSTList[host.state.stream].list?.indices ?? [].indices, id: \.self) { index in
                                                     ZStack{
                                                         RoundedRectangle(cornerRadius: 4)
                                                             .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                                                             .overlay(
                                                                RoundedRectangle(cornerRadius: 6)
                                                                    .stroke(Color.white.opacity(0.85), lineWidth: 2)
                                                             )
                                                             .frame(width: 130)
                                                             .opacity(host.state.host == index ? 1 : 0.2)
                                                         Text(host.VSTList[host.state.stream].list![index].name)
                                                             .font(.custom("DS-Digital", size: 25))
                                                             .foregroundColor(Color.white.opacity(0.85))
                                                             .padding(.vertical,2)
                                                     }.onTapGesture{
                                                         host.state.name = "load host"
                                                         host.state.host = index
                                                         host.state.preset = Array(
                                                             repeating: -1,
                                                             count: host.state.preset.count
                                                         )
                                                         host.setVST()
                                                         //scrollToTheEnd(proxy: proxy)
                                                     }
                                                 }
                                             }
                                         }.id("vst hosts")
                                         Spacer()
                                         if (host.state.stream != -1 && host.state.host != -1){
                                             PresetsView(
                                                vst_list: Binding(
                                                get: {
                                                    if (host.state.stream != -1 && host.state.host != -1){
                                                        host.VSTList[host.state.stream].list?[host.state.host].list ?? []
                                                    }
                                                    else{
                                                        []
                                                    }
                                                },
                                                set: { newValue in
                                                    host.VSTList[host.state.stream].list?[host.state.host].list = newValue
                                                }),
                                                host: host,
                                                proxy: proxy,
                                                file_number: 0
                                             )
                                         }
                                     }
                                 }
                             }
                             
                             RoundedRectangle(cornerRadius: 5)
                                 .fill(Color.white.opacity(0.8))
                                 .frame(width: 3)
                                 .padding(.vertical, 10)
                                 .opacity(host.VSTList.isEmpty ? 0 : 1)
                             
                             if host.presetActual.plugin_count == 0 || host.presetActual.name == "Animation" {
                                 VStack{
                                     if host.state.name == "load setup"{
                                         Text("select collection")
                                     }

                                     else if host.state.name == "load host"{
                                         Text("loading \(host.VSTList[host.state.stream].list?[host.state.host].name ?? "")")
                                         Chargement(width: 10, height: 15)
                                     }
                                     else if host.state.name == "load preset"{
                                         Text("loading \(host.loading_preset)")
                                         Chargement(width: 10, height: 15)
                                     }
                                     else if host.state.name == "host loaded"{
                                         Text("\(host.VSTList[host.state.stream].list?[host.state.host].name ?? "") loaded")
                                     }
                                     else if host.state.name == "preset loaded"{
                                         Text("\(host.loading_preset) loaded")
                                     }
                                     else if host.state.name == "host not installed"{
                                         VStack{
                                             Text("\(host.VSTList[host.state.stream].list?[host.state.host].name ?? "") not installed")
                                             ZStack {
                                                 RoundedRectangle(cornerRadius: 4)
                                                     .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                                                     .overlay(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .stroke(Color.white.opacity(0.85), lineWidth: 2)
                                                     )
                                                     .frame(width: 150)
                                                 Text("install")
                                                     .font(.custom("DS-Digital", size: 25))
                                                     .foregroundColor(Color.white.opacity(0.85))
                                                     .padding(.vertical,2)
                                             }
                                             .onTapGesture {
                                                 host.state.name = "install host"
                                                 host.setVST()
                                             }
                                         }
                                     }
                                     else if host.state.name == "install host"{
                                         Text("installing \(host.VSTList[host.state.stream].list?[host.state.host].name ?? "")")
                                         Chargement(width: 10, height: 15)
                                     }
                                 }
                                 .foregroundColor(Color(red: 1, green: 0.4, blue: 0.8))
                                 .font(.custom("DS-Digital", size: 25))
                                 Spacer()
                             }
                             else{
                                 ScrollView {
                                     VStack(alignment: .leading, spacing: 8) {
                                         ForEach(host.presetActual.plugins, id: \.self) { plugin in
                                             ForEach(plugin.parameters, id: \.self) { parameter in
                                                 ZStack {
                                                     RoundedRectangle(cornerRadius: 4)
                                                         .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                                                         .overlay(
                                                            RoundedRectangle(cornerRadius: 6)
                                                                .stroke(Color.white.opacity(0.85), lineWidth: 2)
                                                         )
                                                         .frame(width: 150)
                                                         .opacity(host.param_to_knob.pluginId == plugin.id
                                                                  && host.param_to_knob.paramId == parameter.id
                                                                  ? 1 : 0.0)
                                                     Text("\(parameter.name) \(parameter.value, format: .number.precision(.fractionLength(1))) \(parameter.unit)")
                                                         .font(.custom("DS-Digital", size: 25))
                                                         .foregroundColor(Color.white.opacity(0.85))
                                                         .padding(.vertical,2)
                                                 }
                                                 .onTapGesture {
                                                     host.param_to_knob.pluginId = plugin.id
                                                     host.param_to_knob.paramId = parameter.id
                                                     host.changeFaderParameters()
                                                 }
                                             }
                                         }
                                     }
                                 }
                                 Spacer()
                             }
                         }.padding(.all, 12)
                     }
                 }
             }
             .frame(height: geo.size.height * 0.5)
         }
     }
 }

struct Chargement: View {
    
    let width: CGFloat
    let height: CGFloat
    
    @State private var loadingBar: [Bool] = Array(repeating: false, count: 5)
    
    var body: some View {
        HStack{
            ForEach(loadingBar.indices, id: \.self) { i in
                Rectangle()
                    .fill(Color(red: 1, green: 0.4, blue: 0.8))
                    .frame(width: width, height: height)
                    .opacity(loadingBar[i] ? 1.0 : 0.0)
            }
        }.onAppear {startAnimation()}
    }
    
    func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                if loadingBar.last == true {
                    loadingBar = Array(repeating: false, count: loadingBar.count)
                } else {
                    for i in loadingBar.indices {
                        if loadingBar[i] == false {
                            loadingBar[i] = true
                            break
                        }
                    }
                }
            }
        }
    }
}

struct RotaryKnob: View {
    
    @ObservedObject var host: RaspberryHost
    var param: FaderParameter
    
    @State private var percentageValue: Double = 0.0
    @State private var up: Bool = true
    
    // Angles de début et fin (en degrés), style potentiomètre audio
    private let minAngle: Double = -140
    private let maxAngle: Double = 140
    
    private var parameterBinding: Binding<Parameter> {
        Binding(
            get: {
                host.presetActual.plugins[param.pluginId]
                    .parameters[param.parameterId]
            },
            set: { newValue in
                host.presetActual.plugins[param.pluginId]
                    .parameters[param.parameterId] = newValue
            }
        )
    }
    
    private var minValue: Double {
        parameterBinding.wrappedValue.min
    }
    
    private var maxValue: Double {
        parameterBinding.wrappedValue.max
    }
    
    // Angle actuel en degrés selon percentageValue
    private var currentAngle: Double {
        minAngle + percentageValue * (maxAngle - minAngle)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = 80.0
            
            ZStack {
                Image("potard")
                    .resizable()
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(currentAngle))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                // Mouvement vertical inversé : monter = augmenter
                                let sensitivity = 0.0005
                                let delta = -gesture.translation.height * sensitivity
                                
                                let newValue = min(max(percentageValue + delta, 0), 1)
                                percentageValue = newValue
                                
                                var updated = parameterBinding.wrappedValue
                                updated.value = newValue * (maxValue - minValue) + minValue
                                parameterBinding.wrappedValue = updated
                            }
                            .onEnded { _ in
                                var p = param
                                p.value = parameterBinding.wrappedValue.value
                                host.setParameter(param: p)
                            }
                    )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            let p = parameterBinding.wrappedValue
            percentageValue = (p.value - p.min) / (p.max - p.min)
            startAnimation()
        }
    }
    
    func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            withAnimation {
                if param.name == "Animation" {
                    if up {
                        percentageValue += 0.007
                        if percentageValue >= 1.1 { up = false }
                    } else {
                        percentageValue -= 0.01
                        if percentageValue <= -0.1 { up = true }
                    }
                }
            }
        }
    }
}

struct VerticalSlider: View {
    
    @ObservedObject var host: RaspberryHost
    var param: FaderParameter
    
    @State private var percentageValue: Double = 0.0
    
    private var parameterBinding: Binding<Parameter> {
        Binding(
            get: {
                host.presetActual.plugins[param.pluginId]
                    .parameters[param.parameterId]
            },
            set: { newValue in
                host.presetActual.plugins[param.pluginId]
                    .parameters[param.parameterId] = newValue
            }
        )
    }
    
    private var minValue: Double {
        parameterBinding.wrappedValue.min
    }
    
    private var maxValue: Double {
        parameterBinding.wrappedValue.max
    }
    
    private func position(height: CGFloat) -> CGFloat {
        CGFloat(percentageValue) * height
    }
    
    @State private var up : Bool = true
    
    var body: some View {
        
        GeometryReader { geometry in
            
            let height = geometry.size.height
            let knobSize: CGFloat = 60
            
            ZStack(alignment: .bottom) {
                
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 6)
                
                Image("Knob")
                    .resizable()
                    .frame(width: 40, height: knobSize)
                    .offset(y: -position(height: height - knobSize))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                
                                let newValue = 1 - Double(gesture.location.y / height)
                                let clamped = min(max(newValue, 0), 1)
                                
                                percentageValue = clamped
                                
                                var updated = parameterBinding.wrappedValue
                                updated.value = clamped * (maxValue - minValue) + minValue
                                parameterBinding.wrappedValue = updated
                            }
                            .onEnded { _ in
                                var p = param
                                p.value = parameterBinding.wrappedValue.value
                                host.setParameter(param: p)
                            }
                    )
            }
        }
        .onAppear {
            let p = parameterBinding.wrappedValue
            percentageValue = (p.value - p.min) / (p.max - p.min)
            Animation()
        }
    }
    
    func Animation() {
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            withAnimation() {
                if (param.name == "Animation"){
                    if (up == true){
                        percentageValue+=0.007
                        if (percentageValue >= 1.1){
                            up = false
                        }
                    }
                    else {
                        percentageValue-=0.01
                        if (percentageValue <= -0.1){
                            up = true
                        }
                    }
                }
            }
        }
    }
}

 struct FadersView: View {
     
     @ObservedObject var host: RaspberryHost
     
     var body: some View {
         GeometryReader { geo in
             HStack{
                 if host.state.stream == 0 {
                     ForEach(host.faderParameters, id: \.self) { param in
                         VStack(alignment: .leading, spacing: 15){
                             VerticalSlider(host: host, param: param)
                                 .frame(height: geo.size.height * 0.4)
                             ZStack {
                                 RoundedRectangle(cornerRadius: 5)
                                     .fill(host.param_to_knob.knobId == param.id ? Color(red: 0.3, green: 0.3, blue: 0.3) : Color(red: 0.1, green: 0.1, blue: 0.1))
                                     .overlay(
                                         RoundedRectangle(cornerRadius: 5)
                                             .stroke(Color.black, lineWidth: 5)
                                     )
                                     .frame(width: 70, height: 30)
                                 Text(host.presetActual.plugins[param.pluginId].parameters[param.parameterId].name)
                                     .font(.custom("DS-Digital", size: 17))
                                     .foregroundColor(host.param_to_knob.knobId == param.id ? Color(red: 1, green: 0.4, blue: 0.8) : Color.white.opacity(0.85))
                                     .lineLimit(1)
                                     .minimumScaleFactor(0.5)
                                     .frame(width: 65, height: 30)
                                     .clipped()
                                     .padding(.horizontal, 2)
                             }
                             .onTapGesture {
                                 host.param_to_knob.knobId = param.id
                                 host.changeFaderParameters()
                             }
                         }
                     }
                 } else {
                     ForEach(
                         host.faderParameters.enumerated().compactMap { index, param in
                             index.isMultiple(of: 2) ? param : nil
                         },
                         id: \.self
                     ) { param in
                         VStack(alignment: .leading, spacing: 15){
                             // First knob in the pair
                             RotaryKnob(host: host, param: param)
                                 .frame(width: 85, height: 85)
                                 .onTapGesture {
                                     host.param_to_knob.knobId = param.id
                                     host.changeFaderParameters()
                                 }
                             ZStack(alignment: .top) {
                                 RoundedRectangle(cornerRadius: 5)
                                     .fill(host.param_to_knob.knobId == param.id || host.param_to_knob.knobId == param.id+1 ? Color(red: 0.3, green: 0.3, blue: 0.3) : Color(red: 0.1, green: 0.1, blue: 0.1))
                                     .overlay(
                                         RoundedRectangle(cornerRadius: 5)
                                             .stroke(Color.black, lineWidth: 5)
                                     )
                                     .frame(width: 70, height: 35)
                                 
                                 VStack(spacing: 0) {
                                     Text(host.presetActual.plugins[param.pluginId].parameters[param.parameterId].name)
                                         .font(.custom("DS-Digital", size: 15))
                                         .foregroundColor(host.param_to_knob.knobId == param.id ? Color(red: 1, green: 0.4, blue: 0.8) : Color.white.opacity(0.85))
                                         .lineLimit(1)
                                         .minimumScaleFactor(0.5)
                                     
                                     if param.id + 1 < host.faderParameters.count {
                                         RoundedRectangle(cornerRadius: 5)
                                             .fill(Color.white.opacity(0.8))
                                             .frame(height: 1)
                                         Text(host.presetActual.plugins[host.faderParameters[param.id+1].pluginId].parameters[host.faderParameters[param.id+1].parameterId].name)
                                             .font(.custom("DS-Digital", size: 15))
                                             .foregroundColor(host.param_to_knob.knobId == param.id+1 ? Color(red: 1, green: 0.4, blue: 0.8) : Color.white.opacity(0.85))
                                             .lineLimit(1)
                                             .minimumScaleFactor(0.5)
                                     }
                                 }
                                 .frame(width: 65, height: 35)
                                 .clipped()
                                 .padding(.horizontal, 2)
                             }
                             // Optional second knob in the pair
                             if param.id + 1 < host.faderParameters.count {
                                 RotaryKnob(host: host, param: host.faderParameters[param.id + 1])
                                     .frame(width: 85, height: 85)
                                     .onTapGesture {
                                         host.param_to_knob.knobId = param.id+1
                                         host.changeFaderParameters()
                                     }
                             }
                         }
                     }
                 }
             }
         }
     }
 }


 struct ContentView: View {
     
     @ObservedObject private var bleManager = BLEManager()
     @ObservedObject var raspberryHost: RaspberryHost
     
     init(test : Bool) {
         let manager = BLEManager()
         _bleManager = ObservedObject(wrappedValue: manager)
         _raspberryHost = ObservedObject(wrappedValue: RaspberryHost(ble_manager: manager, test : test))
     }
     
     var body: some View {
         
         GeometryReader { geo in
             ZStack {
                 
                 if (raspberryHost.state.stream == 0){
                     Image("Arturia")
                         .resizable()
                         .scaledToFill()
                         .ignoresSafeArea()
                 }
                 else{
                     Image("Amp")
                         .resizable()
                         .scaledToFill()
                         .ignoresSafeArea()
                 }
                 
                 HStack{
                     LCDView(
                        ble_message:$bleManager.message,
                        ble_state: $bleManager.isConnected,
                        host:raspberryHost
                     )
                     
                     Spacer().frame(width: 50)
                     
                     FadersView(host:raspberryHost)
                 }.padding(.top, 30)
             }
         }
     }
 }


#Preview{
    ContentView(test : true)
}

