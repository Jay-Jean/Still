import AppKit
import SwiftUI
import Combine
import StillCore

@MainActor final class TimerStore: ObservableObject {
    @Published var session: Session
    @Published var settings = false
    var onTick: (() -> Void)?
    init() {
        if let data = UserDefaults.standard.data(forKey: "session"),
           let saved = try? JSONDecoder().decode(Session.self, from: data) { session = saved }
        else { session = Session() }
        tick()
    }
    var time: String {
        let seconds = Int(ceil(session.remaining))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    func save() {
        if let data = try? JSONEncoder().encode(session) { UserDefaults.standard.set(data, forKey: "session") }
    }
    func tick() {
        if session.tick(at: Date()) {
            if session.sound { NSSound(named: "Glass")?.play() }
            save()
        }
        onTick?()
    }
    func toggle() {
        if session.running { session.pause(at: Date()) } else { session.start(at: Date()) }
        save(); onTick?()
    }
    func reset() { session.reset(); save(); onTick?() }
    func skip() { session.skip(); save(); onTick?() }
}

@MainActor final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = TimerStore()
    var panel: FloatingPanel!
    var status: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 304, height: 392),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: TimerView(store: store, hide: { [weak self] in self?.panel.orderOut(nil) }))
        if !panel.setFrameUsingName("StillPanel") { moveCorner("右下角") }
        panel.setFrameAutosaveName("StillPanel")
        panel.orderFrontRegardless()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        store.onTick = { [weak self] in
            guard let self else { return }
            self.status?.button?.title = "◷ " + self.store.time
        }
        let menu = NSMenu()
        add("显示 / 隐藏小窗", action: #selector(toggleWindow), to: menu, key: "")
        add("开始 / 暂停", action: #selector(toggleTimer), to: menu, key: "")
        menu.addItem(.separator())
        let corners = NSMenu()
        for name in ["左上角", "右上角", "左下角", "右下角"] { add(name, action: #selector(corner(_:)), to: corners, key: "") }
        let positions = NSMenuItem(title: "移到屏幕角落", action: nil, keyEquivalent: "")
        positions.submenu = corners
        menu.addItem(positions)
        menu.addItem(.separator())
        add("退出余刻", action: #selector(quit), to: menu, key: "q")
        status.menu = menu
        store.onTick?()
    }
    func add(_ title: String, action: Selector, to menu: NSMenu, key: String) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }
    @objc func toggleWindow() { if panel.isVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() } }
    @objc func toggleTimer() { store.toggle() }
    @objc func corner(_ sender: NSMenuItem) { moveCorner(sender.title) }
    func moveCorner(_ name: String) {
        let screen = panel.screen ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: name.contains("左") ? frame.minX + 24 : frame.maxX - 328,
                                     y: name.contains("上") ? frame.maxY - 416 : frame.minY + 24))
    }
    @objc func quit() { store.save(); NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel.orderFrontRegardless()
        return true
    }
    func windowDidMove(_ notification: Notification) { panel.saveFrame(usingName: "StillPanel") }
    func applicationWillTerminate(_ notification: Notification) { store.save() }
}

struct Palette {
    let top: Color; let bottom: Color; let mountain: Color; let accent: Color
    static let all = [
        Palette(top: Color(red: 0.18, green: 0.23, blue: 0.30), bottom: Color(red: 0.76, green: 0.50, blue: 0.38), mountain: Color(red: 0.12, green: 0.20, blue: 0.23), accent: Color(red: 1, green: 0.80, blue: 0.57)),
        Palette(top: Color(red: 0.08, green: 0.24, blue: 0.34), bottom: Color(red: 0.39, green: 0.66, blue: 0.68), mountain: Color(red: 0.06, green: 0.22, blue: 0.28), accent: Color(red: 0.70, green: 0.93, blue: 0.93)),
        Palette(top: Color(red: 0.15, green: 0.26, blue: 0.24), bottom: Color(red: 0.58, green: 0.65, blue: 0.44), mountain: Color(red: 0.10, green: 0.21, blue: 0.18), accent: Color(red: 0.87, green: 0.91, blue: 0.64))
    ]
}

struct Landscape: View {
    let palette: Palette
    let progress: Double
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(colors: [palette.top, palette.bottom], startPoint: .top, endPoint: .bottom)
                Circle().fill(palette.accent.opacity(0.16)).frame(width: 100, height: 100)
                    .blur(radius: 22).position(x: w * (0.72 - 0.26 * progress), y: h * (0.38 + 0.37 * progress))
                Circle().fill(palette.accent.opacity(0.85)).frame(width: 30, height: 30)
                    .position(x: w * (0.72 - 0.26 * progress), y: h * (0.38 + 0.37 * progress))
                ForEach(0..<3) { layer in
                    Path { path in
                        let base = h * (0.68 + Double(layer) * 0.09)
                        path.move(to: CGPoint(x: -20, y: h))
                        path.addLine(to: CGPoint(x: -20, y: base + 20))
                        path.addCurve(to: CGPoint(x: w * 0.45, y: base - 25 + Double(layer) * 13), control1: CGPoint(x: w * 0.16, y: base - 75), control2: CGPoint(x: w * 0.27, y: base + 45))
                        path.addCurve(to: CGPoint(x: w + 20, y: base - 10), control1: CGPoint(x: w * 0.72, y: base - 95 + Double(layer) * 20), control2: CGPoint(x: w * 0.8, y: base + 50))
                        path.addLine(to: CGPoint(x: w + 20, y: h)); path.closeSubpath()
                    }.fill(palette.mountain.opacity(0.40 + Double(layer) * 0.26))
                }
                LinearGradient(colors: [.clear, .black.opacity(0.28)], startPoint: .center, endPoint: .bottom)
            }
        }.accessibilityHidden(true)
    }
}

struct TimerView: View {
    @ObservedObject var store: TimerStore
    let hide: () -> Void
    @State private var resetConfirmation = false
    @AppStorage("displayMode") private var displayMode = "ring"
    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    var palette: Palette { Palette.all[max(0, min(2, store.session.theme))] }
    var rest: Bool { store.session.phase == .rest }
    var body: some View {
        ZStack {
            Landscape(palette: palette, progress: 1 - store.session.fraction)
            if displayMode == "sand" {
                palette.top.opacity(0.45)
                SandDrift(session: store.session, accent: palette.accent)
            }
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "circle.lefthalf.filled").font(.system(size: 12))
                    Text("余刻").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button {
                        displayMode = displayMode == "ring" ? "sand" : "ring"
                    } label: {
                        Label(displayMode == "ring" ? "时间环" : "流沙", systemImage: displayMode == "ring" ? "circle.dotted" : "hourglass")
                            .font(.system(size: 10)).padding(.horizontal, 8).padding(.vertical, 5)
                            .background(.white.opacity(0.10), in: Capsule())
                    }.buttonStyle(.plain)
                        .help("随时切换呈现方式，计时继续")
                        .accessibilityLabel(displayMode == "ring" ? "切换到流沙模式" : "切换到时间环模式")
                    icon("slider.horizontal.3", label: "设置") { store.settings.toggle() }
                    icon("minus", label: "收起到菜单栏", action: hide)
                }.foregroundStyle(.white.opacity(0.75)).padding(.horizontal, 20).padding(.top, 17)
                if store.settings { settingsView }
                else { timerFace }
                Spacer(minLength: 0)
                HStack(spacing: 19) {
                    icon("arrow.counterclockwise", label: "重置当前计时") {
                        if store.session.fraction < 1 { resetConfirmation = true } else { store.reset() }
                    }
                    Button(action: store.toggle) {
                        HStack(spacing: 8) {
                            Image(systemName: store.session.running ? "pause.fill" : "play.fill")
                            Text(store.session.running ? "暂停片刻" : (store.session.fraction < 1 ? "继续" : (rest ? "开始休息" : "开始专注")))
                        }.font(.system(size: 12, weight: .semibold)).frame(width: 132, height: 38)
                            .background(.white.opacity(0.92), in: Capsule()).foregroundStyle(palette.mountain)
                    }.buttonStyle(.plain).keyboardShortcut(.space, modifiers: [])
                    icon("forward.end", label: rest ? "切换到专注" : "切换到休息", action: store.skip)
                }.foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 5) {
                    ForEach(0..<4) { index in
                        Circle().fill(index < store.session.completed % 4 || (store.session.completed > 0 && store.session.completed % 4 == 0) ? palette.accent : .white.opacity(0.20)).frame(width: 4, height: 4)
                    }
                    Text("已完成 \(store.session.completed) 次专注").font(.system(size: 10))
                        .padding(.leading, 4)
                }.foregroundStyle(.white.opacity(0.55)).padding(.top, 17).padding(.bottom, 19)
            }
        }
        .frame(width: 304, height: 392)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.16), lineWidth: 1))
        .preferredColorScheme(.dark)
        .onReceive(ticker) { _ in store.tick() }
        .onChange(of: store.session.intention) { store.save() }
        .alert("重新开始这一段？", isPresented: $resetConfirmation) {
            Button("取消", role: .cancel) {}
            Button("重新计时", role: .destructive) { store.reset() }
        } message: { Text("当前这段计时进度会被清除。") }
    }
    var timerFace: some View {
        VStack(spacing: 0) {
            if displayMode == "sand" {
                SandTimerFace(session: store.session, time: store.time, accent: palette.accent)
                    .frame(width: 242, height: 218).padding(.top, 6)
            } else {
            ZStack {
                Circle().stroke(.white.opacity(0.10), lineWidth: 3)
                ForEach(0..<60) { index in
                    Capsule().fill(.white.opacity(index % 5 == 0 ? 0.45 : 0.18))
                        .frame(width: 1, height: index % 5 == 0 ? 6 : 3)
                        .offset(y: -98).rotationEffect(.degrees(Double(index) * 6))
                }
                Circle().trim(from: 0, to: store.session.fraction)
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90)).animation(.linear(duration: 0.25), value: store.session.fraction)
                VStack(spacing: 10) {
                    Text(rest ? "舒 展 · 呼 吸" : "此 刻 · 专 注")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(palette.accent)
                    Text(store.time).font(.system(size: 47, weight: .ultraLight, design: .rounded))
                        .monospacedDigit().foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityLabel("剩余 \(store.time)")
                    Text(rest ? "让注意力，慢慢回来" : "只做眼前这一件事")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                }
            }.frame(width: 218, height: 218).padding(.top, 6)
            }
            TextField("这一刻，想专注什么？", text: $store.session.intention)
                .textFieldStyle(.plain).font(.system(size: 12)).multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85)).padding(.horizontal, 34)
                .padding(.top, 14).padding(.bottom, 16)
                .accessibilityLabel("专注事项")
        }
    }
    var settingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("给自己一点时间").font(.system(size: 18, weight: .light))
            HStack {
                Text("专注"); Spacer()
                Stepper("\(store.session.focusMinutes) 分钟", value: Binding(get: { store.session.focusMinutes }, set: { store.session.configure(focus: $0, rest: store.session.restMinutes); store.save() }), in: 1...90)
            }
            HStack {
                Text("休息"); Spacer()
                Stepper("\(store.session.restMinutes) 分钟", value: Binding(get: { store.session.restMinutes }, set: { store.session.configure(focus: store.session.focusMinutes, rest: $0); store.save() }), in: 1...30)
            }
            Text("调整时长会重置当前计时").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            HStack {
                Text("窗外风景"); Spacer()
                ForEach(0..<3) { i in
                    Button { store.session.theme = i; store.save() } label: {
                        Circle().fill(Palette.all[i].bottom).frame(width: 21, height: 21)
                            .overlay(Circle().stroke(.white.opacity(store.session.theme == i ? 0.9 : 0), lineWidth: 2).padding(-3))
                    }.buttonStyle(.plain).accessibilityLabel(["日落", "海湾", "青山"][i])
                }
            }
            Toggle("结束时轻声提醒", isOn: $store.session.sound).toggleStyle(.switch)
                .onChange(of: store.session.sound) { store.save() }
            Text("专注结束自动休息；休息后等你开启下一段。\n拖动空白处可移动小窗。")
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.6)).lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }.font(.system(size: 12)).foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 25).padding(.top, 22)
    }
    func icon(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 12)).frame(width: 24, height: 24).contentShape(Rectangle()) }
            .buttonStyle(.plain).help(label).accessibilityLabel(label)
    }
}

@main struct StillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}
