import Cocoa
import FlutterMacOS
import SwiftUI

// MARK: - Models

struct BbsDeviceItem: Identifiable, Equatable {
    let id: String
    let formattedId: String
    let hostname: String
    let alias: String
    let displayName: String
    let platform: String
    let username: String
    let online: Bool
    let isSelf: Bool
    let hasPassword: Bool
}

struct BbsKeyPresetItem: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
}

struct BbsKeyOptionItem: Identifiable, Equatable {
    var id: String { code }
    let code: String
    let label: String
}

struct BbsKeyRuleItem: Identifiable, Equatable {
    let id: String
    let name: String
    let desc: String
    let category: String
    let subGroup: String
    let direction: String
    let peer: String
    let srcDisplay: String
    let dstDisplay: String
    var enabled: Bool
    let isCustom: Bool
}

enum BbsNavTab: Int, CaseIterable, Identifiable {
    case devices = 0
    case multiscreen = 1
    case keymap = 2
    case permissions = 3
    case settings = 4
    case assist = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .devices: return "我的设备"
        case .multiscreen: return "多屏与隐私"
        case .keymap: return "按键映射"
        case .permissions: return "本机权限"
        case .settings: return "设置中心"
        case .assist: return "协助与端口"
        }
    }

    var symbol: String {
        switch self {
        case .devices: return "laptopcomputer.and.iphone"
        case .multiscreen: return "sparkles.tv"
        case .keymap: return "keyboard.badge.ellipsis"
        case .permissions: return "checkmark.shield.fill"
        case .settings: return "slider.horizontal.3"
        case .assist: return "point.3.connected.trianglepath.dotted"
        }
    }
}

// MARK: - Observable Store Bridged to Dart Core

final class BbsNativeStore: ObservableObject {
    static let shared = BbsNativeStore()

    private var channel: FlutterMethodChannel?
    private var didPrefillUser = false

    @Published var selectedTab: BbsNavTab = .devices
    @Published var isLogin: Bool = false
    @Published var userName: String = ""
    @Published var displayName: String = ""
    @Published var savedUsername: String = ""
    @Published var myId: String = ""
    @Published var formattedMyId: String = "--- --- ---"
    @Published var myHostname: String = ""
    @Published var tempPass: String = "------"
    @Published var svcReady: Bool = false
    @Published var videoConnCount: Int = 0
    @Published var isDmgVolume: Bool = false
    @Published var permDismissed: Bool = false

    // macOS Permissions
    @Published var canScreenRecord: Bool = true
    @Published var canAccessibility: Bool = true
    @Published var canInputMonitor: Bool = true
    @Published var daemonInstalled: Bool = true

    // Devices
    @Published var devices: [BbsDeviceItem] = []

    // Settings
    @Published var imageQuality: String = "custom"
    @Published var customFps: Double = 144
    @Published var customQuality: Double = 150
    @Published var codecPref: String = "auto"
    @Published var viewStyle: String = "original"
    @Published var hwCodec: Bool = true
    @Published var showQualityMonitor: Bool = false
    @Published var enableSound: Bool = true
    @Published var enableClipboard: Bool = true
    @Published var enableFileCopy: Bool = true
    @Published var enableTrueColor: Bool = false
    @Published var enableHdr: Bool = false
    @Published var directLan: Bool = true
    @Published var forceRelayDefault: Bool = false
    @Published var multiScreenAllWindows: Bool = false
    @Published var privacyStyle: String = "blackout"
    @Published var privacyText: String = "正在远程安全办公中 · 请勿触碰设备"
    @Published var themeMode: String = "system"

    // Key Mappings (540+ Mac & Windows)
    @Published var keyMasterEnabled: Bool = true
    @Published var activeKeyPreset: String = "smart_office"
    @Published var keyTotalCount: Int = 544
    @Published var keyEnabledCount: Int = 180
    @Published var keyPresets: [BbsKeyPresetItem] = []
    @Published var keyOptions: [BbsKeyOptionItem] = []
    @Published var keyRules: [BbsKeyRuleItem] = []

    // UI transient state
    @Published var loginInputUser: String = ""
    @Published var loginInputPass: String = ""
    @Published var loggingIn: Bool = false
    @Published var loginError: String = ""
    @Published var toastMessage: String = ""

    var needsCorePermissions: Bool {
        !canScreenRecord || !canAccessibility
    }

    var onlineDeviceCount: Int {
        devices.filter { $0.online }.count
    }

    private init() {}

    func bindChannel(messenger: FlutterBinaryMessenger) {
        let ch = FlutterMethodChannel(name: "com.bbs.remote/native_ui", binaryMessenger: messenger)
        self.channel = ch
        ch.setMethodCallHandler { [weak self] call, result in
            guard let self = self else {
                result(nil)
                return
            }
            if call.method == "syncState", let jsonStr = call.arguments as? String {
                self.applyStateJson(jsonStr)
                result(true)
            } else if call.method == "syncKeyCatalog", let jsonStr = call.arguments as? String {
                self.applyKeyCatalogJson(jsonStr)
                result(true)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.invoke("requestInitialSync")
        }
    }

    func showToast(_ msg: String) {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                self.toastMessage = msg
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
                guard let self = self, self.toastMessage == msg else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    self.toastMessage = ""
                }
            }
        }
    }

    func invoke(_ method: String, args: [String: Any] = [:], completion: (([String: Any]) -> Void)? = nil) {
        guard let ch = channel else { return }
        ch.invokeMethod(method, arguments: args) { resp in
            if let dict = resp as? [String: Any] {
                completion?(dict)
            } else {
                completion?([:])
            }
        }
    }

    func performLogin() {
        let u = loginInputUser.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = loginInputPass
        guard !u.isEmpty else {
            loginError = "请输入管理员开通的专属账号"
            return
        }
        guard !p.isEmpty else {
            loginError = "请输入登录密码"
            return
        }
        loggingIn = true
        loginError = ""
        invoke("login", args: ["username": u, "password": p]) { [weak self] resp in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.loggingIn = false
                if (resp["ok"] as? Bool) == true {
                    self.loginInputPass = ""
                    self.selectedTab = .devices
                    self.showToast("登录成功 · 已自动绑定本机免密直连")
                } else {
                    self.loginError = (resp["error"] as? String) ?? "账号或密码错误"
                }
            }
        }
    }

    func connectPeer(
        _ dev: BbsDeviceItem,
        fileTransfer: Bool = false,
        portForward: Bool = false,
        forceRelay: Bool = false,
        wirelessExt: Bool = false
    ) {
        if dev.isSelf && !dev.hasPassword {
            showToast("这是当前正在使用的本机设备")
            return
        }
        if portForward {
            showToast("正在打开高速端口映射隧道...")
        } else if fileTransfer {
            showToast("正在打开高速文件传输通道...")
        } else if wirelessExt {
            showToast("正在启动 144Hz 无线扩展副屏模式...")
        } else if forceRelay || forceRelayDefault {
            showToast("正在通过 500Mbps 专线中转通道连接...")
        } else {
            showToast("正在建立多通道 P2P 高速直连...")
        }
        invoke("connectPeer", args: [
            "id": dev.id,
            "isFileTransfer": fileTransfer,
            "isTcpTunneling": portForward,
            "forceRelay": forceRelay,
            "wirelessExt": wirelessExt
        ]) { [weak self] resp in
            if (resp["ok"] as? Bool) == false, let err = resp["error"] as? String {
                self?.showToast(err)
            }
        }
    }

    func toggleRuleOptimistic(_ ruleId: String, enabled: Bool) {
        if let idx = keyRules.firstIndex(where: { $0.id == ruleId }) {
            keyRules[idx].enabled = enabled
        }
        invoke("toggleKeyRule", args: ["id": ruleId, "enabled": enabled])
    }

    private func applyStateJson(_ jsonStr: String) {
        guard let data = jsonStr.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return
        }
        DispatchQueue.main.async {
            self.isLogin = (root["isLogin"] as? Bool) ?? false
            self.userName = (root["userName"] as? String) ?? ""
            self.displayName = (root["displayName"] as? String) ?? ""
            let saved = (root["savedUsername"] as? String) ?? ""
            self.savedUsername = saved
            if !self.didPrefillUser && !saved.isEmpty && self.loginInputUser.isEmpty {
                self.loginInputUser = saved
                self.didPrefillUser = true
            }
            self.myId = (root["myId"] as? String) ?? ""
            let fmtId = (root["formattedMyId"] as? String) ?? ""
            if !fmtId.isEmpty { self.formattedMyId = fmtId }
            self.myHostname = (root["myHostname"] as? String) ?? ""
            let tp = (root["tempPass"] as? String) ?? ""
            if !tp.isEmpty { self.tempPass = tp }
            self.svcReady = (root["svcReady"] as? Bool) ?? false
            self.videoConnCount = (root["videoConnCount"] as? Int) ?? 0
            self.isDmgVolume = (root["isDmgVolume"] as? Bool) ?? false
            self.permDismissed = (root["permDismissed"] as? Bool) ?? false

            self.canScreenRecord = (root["canScreenRecord"] as? Bool) ?? true
            self.canAccessibility = (root["canAccessibility"] as? Bool) ?? true
            self.canInputMonitor = (root["canInputMonitor"] as? Bool) ?? true
            self.daemonInstalled = (root["daemonInstalled"] as? Bool) ?? true

            if let rawDevs = root["devices"] as? [[String: Any]] {
                self.devices = rawDevs.map { d in
                    BbsDeviceItem(
                        id: (d["id"] as? String) ?? "",
                        formattedId: (d["formattedId"] as? String) ?? "",
                        hostname: (d["hostname"] as? String) ?? "",
                        alias: (d["alias"] as? String) ?? "",
                        displayName: (d["displayName"] as? String) ?? "",
                        platform: (d["platform"] as? String) ?? "",
                        username: (d["username"] as? String) ?? "",
                        online: (d["online"] as? Bool) ?? false,
                        isSelf: (d["isSelf"] as? Bool) ?? false,
                        hasPassword: (d["hasPassword"] as? Bool) ?? false
                    )
                }
            }

            if let s = root["settings"] as? [String: Any] {
                self.imageQuality = (s["imageQuality"] as? String) ?? "best"
                if let fps = s["customFps"] as? NSNumber {
                    self.customFps = fps.doubleValue
                }
                if let qual = s["customQuality"] as? NSNumber {
                    self.customQuality = qual.doubleValue
                }
                self.codecPref = (s["codecPref"] as? String) ?? "auto"
                self.viewStyle = (s["viewStyle"] as? String) ?? "adaptive"
                self.hwCodec = (s["hwCodec"] as? Bool) ?? true
                self.showQualityMonitor = (s["showQualityMonitor"] as? Bool) ?? false
                self.enableSound = (s["enableSound"] as? Bool) ?? true
                self.enableClipboard = (s["enableClipboard"] as? Bool) ?? true
                self.enableFileCopy = (s["enableFileCopy"] as? Bool) ?? true
                self.enableTrueColor = (s["enableTrueColor"] as? Bool) ?? false
                self.enableHdr = (s["enableHdr"] as? Bool) ?? false
                self.directLan = (s["directLan"] as? Bool) ?? true
                self.forceRelayDefault = (s["forceRelayDefault"] as? Bool) ?? false
                self.multiScreenAllWindows = (s["multiScreenAllWindows"] as? Bool) ?? false
                self.privacyStyle = (s["privacyStyle"] as? String) ?? "blackout"
                let pt = (s["privacyText"] as? String) ?? ""
                if !pt.isEmpty { self.privacyText = pt }
                self.themeMode = (s["themeMode"] as? String) ?? "system"
            }

            if let km = root["keyMapMeta"] as? [String: Any] {
                self.keyMasterEnabled = (km["masterEnabled"] as? Bool) ?? true
                self.activeKeyPreset = (km["activePreset"] as? String) ?? "smart_office"
                self.keyTotalCount = (km["totalCount"] as? Int) ?? 544
                self.keyEnabledCount = (km["enabledCount"] as? Int) ?? 0
            }
        }
    }

    private func applyKeyCatalogJson(_ jsonStr: String) {
        guard let data = jsonStr.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return
        }
        DispatchQueue.main.async {
            self.keyMasterEnabled = (root["masterEnabled"] as? Bool) ?? true
            self.activeKeyPreset = (root["activePreset"] as? String) ?? "smart_office"
            self.keyTotalCount = (root["totalCount"] as? Int) ?? 544
            self.keyEnabledCount = (root["enabledCount"] as? Int) ?? 0

            if let rawPresets = root["presets"] as? [[String: Any]] {
                self.keyPresets = rawPresets.map { p in
                    BbsKeyPresetItem(
                        id: (p["id"] as? String) ?? "",
                        name: (p["name"] as? String) ?? "",
                        subtitle: (p["subtitle"] as? String) ?? ""
                    )
                }
            }
            if let rawOpts = root["keyOptions"] as? [[String: Any]] {
                self.keyOptions = rawOpts.map { k in
                    BbsKeyOptionItem(
                        code: (k["code"] as? String) ?? "",
                        label: (k["label"] as? String) ?? ""
                    )
                }
            }
            if let rawRules = root["rules"] as? [[String: Any]] {
                self.keyRules = rawRules.map { r in
                    BbsKeyRuleItem(
                        id: (r["id"] as? String) ?? "",
                        name: (r["name"] as? String) ?? "",
                        desc: (r["desc"] as? String) ?? "",
                        category: (r["category"] as? String) ?? "system",
                        subGroup: (r["subGroup"] as? String) ?? "",
                        direction: (r["direction"] as? String) ?? "",
                        peer: (r["peer"] as? String) ?? "all",
                        srcDisplay: (r["srcDisplay"] as? String) ?? "",
                        dstDisplay: (r["dstDisplay"] as? String) ?? "",
                        enabled: (r["enabled"] as? Bool) ?? false,
                        isCustom: (r["isCustom"] as? Bool) ?? false
                    )
                }
            }
        }
    }
}

// MARK: - Window Drag Header Helper (Conflict-free with Sliders & TextFields)

private final class DraggableHeaderNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

struct BbsWindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = DraggableHeaderNSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.clear.cgColor
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - iOS 26/27 Liquid Glass Modifiers & Components

struct BbsLiquidGlassCard: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    if let tint = tint {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint)
                    }

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isDark ? 0.14 : 0.62),
                                    Color.white.opacity(isDark ? 0.03 : 0.22),
                                    Color.cyan.opacity(isDark ? 0.04 : 0.07)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isDark ? 0.46 : 0.92),
                                Color.cyan.opacity(isDark ? 0.28 : 0.35),
                                Color.white.opacity(isDark ? 0.07 : 0.26),
                                Color.indigo.opacity(isDark ? 0.24 : 0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(
                color: Color.black.opacity(isDark ? 0.28 : 0.07),
                radius: 20,
                x: 0,
                y: 10
            )
    }
}

extension View {
    func liquidGlass(radius: CGFloat = 22, tint: Color? = nil) -> some View {
        modifier(BbsLiquidGlassCard(cornerRadius: radius, tint: tint))
    }
}

struct BbsLiquidAuroraBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: isDark
                        ? [
                            Color(red: 0.05, green: 0.08, blue: 0.15).opacity(0.78),
                            Color(red: 0.07, green: 0.11, blue: 0.21).opacity(0.72),
                            Color(red: 0.04, green: 0.07, blue: 0.14).opacity(0.82)
                        ]
                        : [
                            Color(red: 0.92, green: 0.96, blue: 1.0).opacity(0.76),
                            Color(red: 0.95, green: 0.97, blue: 1.0).opacity(0.70),
                            Color(red: 0.90, green: 0.94, blue: 0.99).opacity(0.78)
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.cyan.opacity(isDark ? 0.26 : 0.28),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 280
                        )
                    )
                    .frame(width: 540, height: 540)
                    .offset(x: -geo.size.width * 0.28, y: -geo.size.height * 0.30)
                    .blur(radius: 40)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.indigo.opacity(isDark ? 0.28 : 0.22),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 300
                        )
                    )
                    .frame(width: 580, height: 580)
                    .offset(x: geo.size.width * 0.32, y: -geo.size.height * 0.20)
                    .blur(radius: 50)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.12, green: 0.68, blue: 0.96).opacity(isDark ? 0.20 : 0.18),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 260
                        )
                    )
                    .frame(width: 500, height: 500)
                    .offset(x: geo.size.width * 0.18, y: geo.size.height * 0.34)
                    .blur(radius: 45)
            }
        }
        .ignoresSafeArea()
    }
}

struct BbsLiquidActionButton: View {
    let title: String
    let symbol: String?
    var prominent: Bool = true
    var compact: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol = symbol {
                    Image(systemName: symbol)
                        .font(.system(size: compact ? 12 : 13.5, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: compact ? 12.5 : 13.5, weight: .semibold))
            }
            .padding(.horizontal, compact ? 13 : 18)
            .padding(.vertical, compact ? 7 : 9.5)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(
                Group {
                    if prominent {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.06, green: 0.62, blue: 0.98),
                                        Color(red: 0.24, green: 0.42, blue: 0.96)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
                            )
                            .shadow(color: Color.cyan.opacity(hovering ? 0.42 : 0.25), radius: hovering ? 14 : 8, y: 4)
                    } else {
                        Capsule(style: .continuous)
                            .fill(.thinMaterial)
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.32), lineWidth: 1)
                            )
                    }
                }
            )
            .scaleEffect(hovering ? 1.02 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.76), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Root Container View

struct BbsLiquidGlassRootView: View {
    @ObservedObject var store: BbsNativeStore

    private var preferredScheme: ColorScheme? {
        if store.themeMode == "light" { return .light }
        if store.themeMode == "dark" { return .dark }
        return nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            BbsLiquidAuroraBackdrop()

            // Top invisible native window drag bar (leaves controls clickable below)
            VStack(spacing: 0) {
                BbsWindowDragArea()
                    .frame(height: 34)
                Spacer()
            }
            .ignoresSafeArea()

            if !store.isLogin {
                BbsLiquidLoginView(store: store)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                BbsLiquidWorkspaceView(store: store)
                    .transition(.opacity)
            }

            // Dynamic Island style Liquid Glass Toast
            if !store.toastMessage.isEmpty {
                HStack(spacing: 9) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.cyan)
                        .font(.system(size: 13, weight: .bold))
                    Text(store.toastMessage)
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .liquidGlass(radius: 24)
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(99)
            }
        }
        .frame(minWidth: 940, minHeight: 620)
        .preferredColorScheme(preferredScheme)
    }
}

// MARK: - 1. Liquid Glass Login Screen

struct BbsLiquidLoginView: View {
    @ObservedObject var store: BbsNativeStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Brand Squircle Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.35), Color.indigo.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 76, height: 76)
                        .blur(radius: 12)

                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                        )
                }

                VStack(spacing: 5) {
                    Text("BBS-Remote")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("iOS 27 液态玻璃原生架构 · 400FPS 专线一键远控")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16))
                        TextField("请输入管理员开通的专属账号", text: $store.loginInputUser)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .onSubmit { store.performLogin() }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                            )
                    )

                    HStack(spacing: 10) {
                        Image(systemName: "lock.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16))
                        SecureField("请输入登录密码", text: $store.loginInputPass)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .onSubmit { store.performLogin() }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                            )
                    )
                }

                if !store.loginError.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(store.loginError)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.red.opacity(0.12))
                    )
                }

                Button(action: { store.performLogin() }) {
                    HStack(spacing: 8) {
                        if store.loggingIn {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "bolt.horizontal.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text(store.loggingIn ? "正在安全认证..." : "立即登录并绑定本机")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.05, green: 0.62, blue: 0.98),
                                        Color(red: 0.26, green: 0.40, blue: 0.96)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
                            )
                            .shadow(color: Color.cyan.opacity(0.32), radius: 14, y: 6)
                    )
                }
                .buttonStyle(.plain)
                .disabled(store.loggingIn)

                HStack(spacing: 7) {
                    Circle()
                        .fill(store.svcReady ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                        .shadow(color: (store.svcReady ? Color.green : Color.orange).opacity(0.6), radius: 5)
                    Text(store.svcReady ? "专线信令与 P2P 通道已就绪 · 本机识别码 \(store.formattedMyId)" : "正在连接专属高速节点...")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(34)
            .frame(width: 420)
            .liquidGlass(radius: 30)

            Spacer()

            if store.isDmgVolume {
                BbsDmgBannerView(store: store)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 18)
            }
        }
    }
}

// MARK: - 2. Main Liquid Glass Workspace

struct BbsLiquidWorkspaceView: View {
    @ObservedObject var store: BbsNativeStore

    var body: some View {
        HStack(spacing: 16) {
            // Floating Liquid Glass Sidebar
            BbsLiquidSidebar(store: store)
                .frame(width: 236)

            // Active Content Pane
            VStack(spacing: 12) {
                if store.isDmgVolume {
                    BbsDmgBannerView(store: store)
                }
                if store.selectedTab == .devices && store.needsCorePermissions && !store.permDismissed {
                    BbsPermQuickBanner(store: store)
                }

                Group {
                    switch store.selectedTab {
                    case .devices:
                        BbsMyDevicesPage(store: store)
                    case .multiscreen:
                        BbsMultiScreenPrivacyPage(store: store)
                    case .keymap:
                        BbsKeyMappingPage(store: store)
                    case .permissions:
                        BbsPermissionsPage(store: store)
                    case .settings:
                        BbsSettingsPage(store: store)
                    case .assist:
                        BbsManualAssistPage(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
        .padding(.horizontal, 16)
    }
}

struct BbsLiquidSidebar: View {
    @ObservedObject var store: BbsNativeStore
    @Namespace private var navNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Reserve top space for macOS native traffic light buttons
            Spacer().frame(height: 22)

            // App Brand Header
            HStack(spacing: 11) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("BBS-Remote")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    HStack(spacing: 5) {
                        Circle()
                            .fill(store.svcReady ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(store.svcReady ? "P2P · 400Hz 就绪" : "节点重连中")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 6)

            Divider().opacity(0.35)

            // Liquid Glass Navigation Capsules
            VStack(spacing: 6) {
                ForEach(BbsNavTab.allCases) { tab in
                    let selected = store.selectedTab == tab
                    Button {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                            store.selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 14.5, weight: .semibold))
                                .frame(width: 22)
                                .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.82))

                            Text(tab.title)
                                .font(.system(size: 13.5, weight: selected ? .bold : .medium))
                                .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.88))

                            Spacer()

                            navTrailingBadge(for: tab, selected: selected)
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(
                            ZStack {
                                if selected {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.06, green: 0.60, blue: 0.97),
                                                    Color(red: 0.27, green: 0.41, blue: 0.95)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.42), lineWidth: 1)
                                        )
                                        .shadow(color: Color.cyan.opacity(0.28), radius: 10, y: 4)
                                        .matchedGeometryEffect(id: "ACTIVE_NAV_PILL", in: navNamespace)
                                }
                            }
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Local ID & Logged-in Account Capsule
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 9) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.indigo],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 34, height: 34)
                        Text(String((store.displayName.isEmpty ? "U" : store.displayName).prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.displayName.isEmpty ? store.userName : store.displayName)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                        Text("@\(store.userName) · 免密已激活")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        store.invoke("logout")
                        store.showToast("已安全退出当前账号")
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(Circle().fill(Color.primary.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                    .help("退出登录")
                }

                Divider().opacity(0.25)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("本机识别码")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(store.formattedMyId)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(store.myId, forType: .string)
                        store.showToast("已复制本机识别码 \(store.formattedMyId)")
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                    .help("复制本机识别码")
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    )
            )
        }
        .padding(14)
        .liquidGlass(radius: 26)
    }

    @ViewBuilder
    private func navTrailingBadge(for tab: BbsNavTab, selected: Bool) -> some View {
        switch tab {
        case .devices:
            if !store.devices.isEmpty {
                Text("\(store.onlineDeviceCount)/\(store.devices.count)")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .foregroundStyle(selected ? Color.white : Color.cyan)
                    .background(
                        Capsule().fill(selected ? Color.white.opacity(0.22) : Color.cyan.opacity(0.15))
                    )
            }
        case .multiscreen:
            Text("满血")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .padding(.horizontal, 6.5)
                .padding(.vertical, 2)
                .foregroundStyle(selected ? Color.white : Color.indigo)
                .background(
                    Capsule().fill(selected ? Color.white.opacity(0.22) : Color.indigo.opacity(0.16))
                )
        case .keymap:
            Text("\(store.keyTotalCount)+")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .foregroundStyle(selected ? Color.white : Color.cyan)
                .background(
                    Capsule().fill(selected ? Color.white.opacity(0.22) : Color.cyan.opacity(0.15))
                )
        case .permissions:
            if store.needsCorePermissions {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(selected ? Color.white : Color.green)
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Banners

struct BbsDmgBannerView: View {
    @ObservedObject var store: BbsNativeStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 18))
                .foregroundStyle(.cyan)
            Text("当前正在磁盘镜像内运行，建议一键移入「应用程序」以保持系统权限长期有效")
                .font(.system(size: 12.5, weight: .medium))
            Spacer()
            BbsLiquidActionButton(title: "一键安装到应用程序", symbol: "sparkles", compact: true) {
                store.invoke("installToApps")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .liquidGlass(radius: 16, tint: Color.cyan.opacity(0.10))
    }
}

struct BbsPermQuickBanner: View {
    @ObservedObject var store: BbsNativeStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.orange)
            Text("本机尚未完成屏幕录制或辅助功能授权，其他电脑远控本机时可能无法显示画面或控制键鼠")
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
            Spacer()
            BbsLiquidActionButton(title: "前往配置权限", symbol: "checkmark.shield", compact: true) {
                store.selectedTab = .permissions
            }
            Button {
                store.invoke("dismissPermBanner")
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .liquidGlass(radius: 16, tint: Color.orange.opacity(0.10))
    }
}

// MARK: - Page 1: My Devices (一键免密远程)

struct BbsMyDevicesPage: View {
    @ObservedObject var store: BbsNativeStore
    @State private var searchText: String = ""
    @State private var renamingDevice: BbsDeviceItem?
    @State private var renameText: String = ""
    @State private var deletingDevice: BbsDeviceItem?

    private var filteredDevices: [BbsDeviceItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sorted = store.devices.sorted { a, b in
            if a.isSelf != b.isSelf { return !a.isSelf } // Put remote devices first for 1-click access
            if a.online != b.online { return a.online }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
        guard !q.isEmpty else { return sorted }
        return sorted.filter {
            $0.displayName.lowercased().contains(q) ||
            $0.hostname.lowercased().contains(q) ||
            $0.id.contains(q) ||
            $0.platform.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header + Search Capsule
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("我的设备")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("同一账号下设备自动同步，点击「一键远程」毫秒级免密直连，支持远程直接操控对端 BBS-Remote")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                    TextField("搜索设备名或 ID...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .frame(width: 170)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .liquidGlass(radius: 18)

                BbsLiquidActionButton(title: "刷新列表", symbol: "arrow.clockwise", prominent: false, compact: true) {
                    store.invoke("refreshDevices")
                    store.showToast("已同步最新设备在线状态")
                }
            }
            .padding(.top, 6)

            // Local Machine Status Strip
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.28), Color.blue.opacity(0.22)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.cyan)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(store.myHostname.isEmpty ? "当前 Mac 设备" : store.myHostname)
                            .font(.system(size: 15, weight: .bold))
                        Text("本机 · 免密被控已就绪")
                            .font(.system(size: 10.5, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2.5)
                            .foregroundStyle(.cyan)
                            .background(Capsule().fill(Color.cyan.opacity(0.16)))
                        if store.videoConnCount > 0 {
                            Text("正在被远控 (\(store.videoConnCount))")
                                .font(.system(size: 10.5, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2.5)
                                .foregroundStyle(.green)
                                .background(Capsule().fill(Color.green.opacity(0.18)))
                        }
                    }
                    Text("设备识别码：\(store.formattedMyId)  ·  支持 P2P 打洞直连与 400FPS 超高帧率")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                BbsLiquidActionButton(title: "复制本机 ID", symbol: "doc.on.doc", prominent: false, compact: true) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(store.myId, forType: .string)
                    store.showToast("已复制本机 ID：\(store.formattedMyId)")
                }
            }
            .padding(16)
            .liquidGlass(radius: 20)

            // Device Grid
            ScrollView {
                if filteredDevices.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "laptopcomputer.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text("暂无匹配的绑定设备")
                            .font(.system(size: 15, weight: .semibold))
                        Text("在另一台 Mac 或 Windows 电脑登录同一账号，即可在此一键免密远控")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 70)
                    .liquidGlass(radius: 22)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 300), spacing: 14),
                            GridItem(.flexible(minimum: 300), spacing: 14)
                        ],
                        spacing: 14
                    ) {
                        ForEach(filteredDevices) { dev in
                            BbsDeviceGlassCard(
                                dev: dev,
                                onConnect: { store.connectPeer(dev, fileTransfer: false) },
                                onRelayConnect: { store.connectPeer(dev, forceRelay: true) },
                                onWirelessExt: { store.connectPeer(dev, wirelessExt: true) },
                                onTransfer: { store.connectPeer(dev, fileTransfer: true) },
                                onPortForward: { store.connectPeer(dev, portForward: true) },
                                onRename: {
                                    renameText = dev.alias.isEmpty ? dev.hostname : dev.alias
                                    renamingDevice = dev
                                },
                                onDelete: { deletingDevice = dev }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .sheet(item: $renamingDevice) { dev in
            VStack(alignment: .leading, spacing: 16) {
                Text("修改设备备注名称")
                    .font(.system(size: 17, weight: .bold))
                TextField("例如：办公室 MacBook Pro / 家里电竞主机", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 340)
                HStack {
                    Spacer()
                    Button("取消") { renamingDevice = nil }
                    BbsLiquidActionButton(title: "保存备注", symbol: "checkmark", compact: true) {
                        store.invoke("renamePeer", args: ["id": dev.id, "alias": renameText])
                        store.showToast("已更新设备备注名称")
                        renamingDevice = nil
                    }
                }
            }
            .padding(24)
        }
        .sheet(item: $deletingDevice) { dev in
            VStack(alignment: .leading, spacing: 16) {
                Text("移除绑定设备")
                    .font(.system(size: 17, weight: .bold))
                Text("确定从设备列表中移除「\(dev.displayName)」吗？")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 320, alignment: .leading)
                HStack {
                    Spacer()
                    Button("取消") { deletingDevice = nil }
                    BbsLiquidActionButton(title: "确认移除", symbol: "trash", compact: true) {
                        store.invoke("deletePeer", args: ["id": dev.id])
                        store.showToast("已移除设备")
                        deletingDevice = nil
                    }
                }
            }
            .padding(24)
        }
    }
}

struct BbsDeviceGlassCard: View {
    let dev: BbsDeviceItem
    let onConnect: () -> Void
    let onRelayConnect: () -> Void
    let onWirelessExt: () -> Void
    let onTransfer: () -> Void
    let onPortForward: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    private var platformIcon: String {
        let p = dev.platform.lowercased()
        if p.contains("mac") || p.contains("darwin") { return "laptopcomputer" }
        if p.contains("win") { return "pc" }
        if p.contains("android") || p.contains("ios") { return "iphone" }
        return "desktopcomputer"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            dev.online
                                ? LinearGradient(
                                    colors: [Color.cyan.opacity(0.25), Color.indigo.opacity(0.22)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.gray.opacity(0.16), Color.gray.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 46, height: 46)

                    Image(systemName: platformIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(dev.online ? Color.cyan : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(dev.displayName)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)

                        if dev.isSelf {
                            Text("本机")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .foregroundStyle(.cyan)
                                .background(Capsule().fill(Color.cyan.opacity(0.16)))
                        }
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(dev.online ? Color.green : Color.gray.opacity(0.6))
                            .frame(width: 7, height: 7)
                        Text(dev.online ? "在线 · 支持 P2P" : "离线")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(dev.online ? Color.green : Color.secondary)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(dev.platform.isEmpty ? "Desktop" : dev.platform)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Menu {
                    if !dev.isSelf {
                        Button("手动切换 500Mbps 专线中转连接", action: onRelayConnect)
                        Button("作为 144Hz 无线扩展副屏连接", action: onWirelessExt)
                        Divider()
                    }
                    Button("高速远程文件传输", action: onTransfer)
                    if !dev.isSelf {
                        Button("TCP 端口映射高速中转通道", action: onPortForward)
                    }
                    Divider()
                    Button("修改备注名称", action: onRename)
                    if !dev.isSelf {
                        Button("移除该设备", role: .destructive, action: onDelete)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }

            Divider().opacity(0.22)

            HStack(spacing: 8) {
                Text("ID: \(dev.formattedId.isEmpty ? dev.id : dev.formattedId)")
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if !dev.isSelf {
                    BbsLiquidActionButton(title: "端口映射", symbol: "point.3.connected.trianglepath.dotted", prominent: false, compact: true, action: onPortForward)
                    BbsLiquidActionButton(title: "传文件", symbol: "folder", prominent: false, compact: true, action: onTransfer)
                    BbsLiquidActionButton(title: "一键远程", symbol: "play.fill", prominent: true, compact: true, action: onConnect)
                } else {
                    Text("当前主控端 · 多通道已解锁")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .liquidGlass(radius: 20)
        .scaleEffect(hovering ? 1.01 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: hovering)
        .onHover { hovering = $0 }
    }
}

// MARK: - Page 2: Key Mapping Center (540+ Mac & Windows Mappings)

struct BbsKeyMappingPage: View {
    @ObservedObject var store: BbsNativeStore
    @State private var searchQuery: String = ""
    @State private var categoryFilter: String = "all"
    @State private var peerFilter: String = "all"
    @State private var showingAddModal: Bool = false

    private var filteredRules: [BbsKeyRuleItem] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.keyRules.filter { r in
            if categoryFilter != "all" && r.category != categoryFilter { return false }
            if peerFilter == "windows" && r.peer != "windows" && r.peer != "all" { return false }
            if peerFilter == "macos" && r.peer != "macos" && r.peer != "all" { return false }
            if peerFilter == "enabled" && !r.enabled { return false }
            if !q.isEmpty {
                let hay = "\(r.name) \(r.desc) \(r.subGroup) \(r.srcDisplay) \(r.dstDisplay)".lowercased()
                if !hay.contains(q) { return false }
            }
            return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("按键映射中心")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("内置 \(store.keyTotalCount) 项 Mac ⇄ Windows 系统、办公、开发设计、3D 小键盘与电竞游戏键位，实时无感转换")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                BbsLiquidActionButton(title: "新增自定义映射", symbol: "plus", prominent: true, compact: false) {
                    showingAddModal = true
                }
            }
            .padding(.top, 6)

            // Master Engine Switch Card
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan, Color.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: "keyboard.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 17, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("全局按键映射引擎 · 共 \(store.keyTotalCount) 项规则（当前已启用 \(store.keyEnabledCount) 项）")
                        .font(.system(size: 14, weight: .bold))
                    Text("自动识别远端 Windows / macOS 系统，支持单键长按蓄力（FPS/原神/MMO）与组合键防卡键保护")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { store.keyMasterEnabled },
                    set: { val in
                        store.keyMasterEnabled = val
                        store.invoke("setKeyMasterEnabled", args: ["enabled": val])
                        store.showToast(val ? "已启用全局按键映射引擎" : "已暂停全局按键映射")
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding(14)
            .liquidGlass(radius: 18)

            // Scene Presets Strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.keyPresets) { preset in
                        let active = store.activeKeyPreset == preset.id
                        Button {
                            store.activeKeyPreset = preset.id
                            store.invoke("applyKeyPreset", args: ["presetId": preset.id])
                            store.showToast("已切换方案：\(preset.name)")
                        } label: {
                            Text(preset.name)
                                .font(.system(size: 12, weight: active ? .bold : .medium))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .foregroundStyle(active ? Color.white : Color.primary)
                                .background(
                                    Group {
                                        if active {
                                            Capsule(style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color(red: 0.06, green: 0.62, blue: 0.98), Color.indigo],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                        } else {
                                            Capsule(style: .continuous)
                                                .fill(.thinMaterial)
                                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                                        }
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                        .help(preset.subtitle)
                    }
                }
            }

            // Search + Category + OS Filter Bar
            HStack(spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12.5))
                    TextField("搜索 540+ 快捷键（如：复制、截图、VS Code、PS、Blender、原神、FPS、LOL）...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .liquidGlass(radius: 14)

                ForEach([
                    ("all", "全部"),
                    ("system", "系统互转"),
                    ("office", "办公/浏览器"),
                    ("creative", "开发/设计/3D"),
                    ("gaming", "电竞/游戏"),
                    ("custom", "自定义")
                ], id: \.0) { catId, label in
                    let sel = categoryFilter == catId
                    Button {
                        categoryFilter = catId
                    } label: {
                        Text(label)
                            .font(.system(size: 11.5, weight: sel ? .bold : .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6.5)
                            .foregroundStyle(sel ? Color.cyan : Color.primary.opacity(0.8))
                            .background(
                                Capsule().fill(sel ? Color.cyan.opacity(0.18) : Color.primary.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Picker("", selection: $peerFilter) {
                    Text("全部系统").tag("all")
                    Text("远端 Win").tag("windows")
                    Text("远端 Mac").tag("macos")
                    Text("仅已启用").tag("enabled")
                }
                .labelsHidden()
                .frame(width: 105)
            }

            // Virtualized 540+ Key Rules List
            ScrollView {
                if filteredRules.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("没有找到匹配的按键映射")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .liquidGlass(radius: 18)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredRules) { rule in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 7) {
                                        Text(rule.direction)
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .foregroundStyle(.cyan)
                                            .background(Capsule().fill(Color.cyan.opacity(0.16)))

                                        Text(rule.name)
                                            .font(.system(size: 13.5, weight: .semibold))
                                            .lineLimit(1)
                                    }
                                    Text("\(rule.subGroup) · \(rule.desc)")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text(rule.srcDisplay)
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.primary.opacity(0.07))
                                    )

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.cyan)

                                Text(rule.dstDisplay)
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.cyan)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.cyan.opacity(0.14))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .strokeBorder(Color.cyan.opacity(0.35), lineWidth: 1)
                                            )
                                    )

                                if rule.isCustom {
                                    Button {
                                        store.invoke("deleteCustomKeyRule", args: ["id": rule.id])
                                        store.showToast("已删除自定义映射")
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                            .padding(4)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Toggle("", isOn: Binding(
                                    get: { rule.enabled },
                                    set: { val in store.toggleRuleOptimistic(rule.id, enabled: val) }
                                ))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .liquidGlass(radius: 15, tint: rule.enabled ? Color.cyan.opacity(0.03) : nil)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .sheet(isPresented: $showingAddModal) {
            BbsAddCustomKeyRuleSheet(store: store, isPresented: $showingAddModal)
        }
    }
}

struct BbsAddCustomKeyRuleSheet: View {
    @ObservedObject var store: BbsNativeStore
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var peer: String = "all"
    @State private var srcKey: String = "c"
    @State private var srcMeta: Bool = true
    @State private var srcCtrl: Bool = false
    @State private var srcAlt: Bool = false
    @State private var srcShift: Bool = false

    @State private var dstKey: String = "c"
    @State private var dstCtrl: Bool = true
    @State private var dstMeta: Bool = false
    @State private var dstAlt: Bool = false
    @State private var dstShift: Bool = false

    private var sourceKeyChoices: [BbsKeyOptionItem] {
        store.keyOptions.filter {
            !["ctrl_alt_del", "lock_screen", "shift", "ctrl", "alt", "meta"].contains($0.code)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新增自定义按键映射")
                .font(.system(size: 18, weight: .bold))

            TextField("规则名称（例如：一键连招 / Photoshop 快速导出）", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("生效远端系统：")
                    .font(.system(size: 13, weight: .semibold))
                Picker("", selection: $peer) {
                    Text("Mac & Windows 通用").tag("all")
                    Text("仅远端 Windows").tag("windows")
                    Text("仅远端 macOS").tag("macos")
                }
                .pickerStyle(.segmented)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("当本机按下（触发键位）：")
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 14) {
                    Toggle("⌘ Cmd", isOn: $srcMeta)
                    Toggle("⌃ Ctrl", isOn: $srcCtrl)
                    Toggle("⌥ Option", isOn: $srcAlt)
                    Toggle("⇧ Shift", isOn: $srcShift)
                }
                Picker("本机主键", selection: $srcKey) {
                    ForEach(sourceKeyChoices) { item in
                        Text(item.label).tag(item.code)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("发送至远端电脑（目标键位）：")
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 14) {
                    Toggle("Ctrl", isOn: $dstCtrl)
                    Toggle("Win / ⌘ Cmd", isOn: $dstMeta)
                    Toggle("Alt / ⌥ Opt", isOn: $dstAlt)
                    Toggle("Shift", isOn: $dstShift)
                }
                Picker("远端目标按键", selection: $dstKey) {
                    ForEach(store.keyOptions) { item in
                        Text(item.label).tag(item.code)
                    }
                }
            }

            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                BbsLiquidActionButton(title: "保存并立即启用", symbol: "checkmark.circle.fill", compact: true) {
                    store.invoke("addCustomKeyRule", args: [
                        "name": name.isEmpty ? "自定义按键映射" : name,
                        "peer": peer,
                        "srcKey": srcKey,
                        "srcCtrl": srcCtrl,
                        "srcAlt": srcAlt,
                        "srcShift": srcShift,
                        "srcMeta": srcMeta,
                        "dstKey": dstKey,
                        "dstCtrl": dstCtrl,
                        "dstAlt": dstAlt,
                        "dstShift": dstShift,
                        "dstMeta": dstMeta
                    ])
                    store.showToast("已添加自定义按键映射并实时生效")
                    isPresented = false
                }
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}

// MARK: - Page 3: macOS Permissions & TCC Repair

struct BbsPermissionsPage: View {
    @ObservedObject var store: BbsNativeStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本机被控系统权限")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("开启以下 macOS 系统授权后，其他设备即可高清流畅观看并控制本台 Mac")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)

                permRow(
                    title: "屏幕录制与系统音频权限 (Screen Recording)",
                    desc: "必需权限：允许本机向您的其他设备传输 400FPS 高清桌面画面",
                    symbol: "display",
                    granted: store.canScreenRecord,
                    actionTitle: "去系统设置开启"
                ) {
                    store.invoke("openPerm", args: ["kind": "screen"])
                }

                permRow(
                    title: "辅助功能控制权限 (Accessibility)",
                    desc: "必需权限：允许远端控制本机的鼠标点击、滚轮与键盘输入（含操控本机 BBS-Remote 窗口）",
                    symbol: "cursorarrow.click.2",
                    granted: store.canAccessibility,
                    actionTitle: "去系统设置开启"
                ) {
                    store.invoke("openPerm", args: ["kind": "accessibility"])
                }

                permRow(
                    title: "输入监控权限 (Input Monitoring)",
                    desc: "推荐开启：启用底层全局热键与游戏级低延迟按键映射抓取",
                    symbol: "keyboard.badge.eye",
                    granted: store.canInputMonitor,
                    actionTitle: "去系统设置开启"
                ) {
                    store.invoke("openPerm", args: ["kind": "input"])
                }

                permRow(
                    title: "后台常驻无人值守服务 (LaunchDaemon)",
                    desc: "推荐安装：支持开机锁屏界面自动在线，随时随地一键唤醒远控",
                    symbol: "bolt.shield.fill",
                    granted: store.daemonInstalled,
                    actionTitle: "一键安装服务"
                ) {
                    store.invoke("openPerm", args: ["kind": "daemon"])
                }

                // TCC Self-Heal Card
                HStack(spacing: 14) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("覆盖升级后提示已开启权限但仍等待画面？")
                            .font(.system(size: 14, weight: .bold))
                        Text("macOS 更新新版客户端后可能保留旧签名缓存，点击右侧一键清理重授并重启即可立即恢复")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    BbsLiquidActionButton(title: "重置修复权限识别", symbol: "arrow.triangle.2.circlepath", prominent: false, compact: true) {
                        store.invoke("repairPerms")
                        store.showToast("已重置旧版权限缓存，请在系统弹窗中重新勾选")
                    }
                    BbsLiquidActionButton(title: "立即重启客户端", symbol: "power", prominent: true, compact: true) {
                        store.invoke("relaunchApp")
                    }
                }
                .padding(18)
                .liquidGlass(radius: 20, tint: Color.cyan.opacity(0.06))
            }
            .padding(.bottom, 12)
        }
        .scrollContentBackground(.hidden)
    }

    private func permRow(
        title: String,
        desc: String,
        symbol: String,
        granted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill((granted ? Color.green : Color.orange).opacity(0.16))
                    .frame(width: 44, height: 44)
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(granted ? Color.green : Color.orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14.5, weight: .bold))
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if granted {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("已就绪")
                }
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.green.opacity(0.15)))
            } else {
                BbsLiquidActionButton(title: actionTitle, symbol: "arrow.up.forward.app", prominent: true, compact: true, action: action)
            }
        }
        .padding(16)
        .liquidGlass(radius: 18)
    }
}

// MARK: - Page 4: Settings Center (60~400Hz & Mbps)

struct BbsSettingsPage: View {
    @ObservedObject var store: BbsNativeStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设置中心")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("自定义 400FPS 超高刷画质、硬件编解码器、P2P 直连策略与液态玻璃外观")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)

                // High Refresh Rate & 500Mbps Bitrate Presets
                VStack(alignment: .leading, spacing: 12) {
                    Text("4K 原画 · 高刷 · 500Mbps 满血预设")
                        .font(.system(size: 14.5, weight: .bold))

                    HStack(spacing: 10) {
                        presetCard(mode: "custom", fps: 144, mbps: 500, title: "4K 原画 · 144Hz", desc: "500Mbps 满血原画")
                        presetCard(mode: "custom", fps: 240, mbps: 300, title: "电竞极速 · 240Hz", desc: "300Mbps 超低延迟")
                        presetCard(mode: "custom", fps: 400, mbps: 500, title: "极限超频 · 400Hz", desc: "500Mbps 解锁极限")
                        presetCard(mode: "custom", fps: 60, mbps: 30, title: "均衡省流 · 60Hz", desc: "30Mbps 移动流畅")
                    }

                    Divider().opacity(0.25)

                    HStack {
                        Text("目标帧率上限：\(Int(store.customFps)) FPS")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 195, alignment: .leading)
                        Slider(value: $store.customFps, in: 30...400, step: 10) { editing in
                            if !editing {
                                store.invoke("updateSetting", args: ["key": "customFps", "value": store.customFps])
                            }
                        }
                        .tint(.cyan)
                    }

                    HStack {
                        Text("自定义码率上限：\(Int(store.customQuality)) Mbps")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 195, alignment: .leading)
                        Slider(value: $store.customQuality, in: 5...500, step: 5) { editing in
                            if !editing {
                                store.invoke("updateSetting", args: ["key": "customQuality", "value": store.customQuality])
                            }
                        }
                        .tint(.cyan)
                    }
                }
                .padding(18)
                .liquidGlass(radius: 20)

                // Codec & Appearance
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("视频硬件编码偏好")
                            .font(.system(size: 14, weight: .bold))
                        Picker("", selection: Binding(
                            get: { store.codecPref },
                            set: { v in
                                store.codecPref = v
                                store.invoke("updateSetting", args: ["key": "codecPref", "value": v])
                            }
                        )) {
                            Text("自动优选").tag("auto")
                            Text("HEVC (H.265)").tag("h265")
                            Text("AVC (H.264)").tag("h264")
                            Text("AV1 超清").tag("av1")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .liquidGlass(radius: 18)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("液态玻璃界面外观")
                            .font(.system(size: 14, weight: .bold))
                        Picker("", selection: Binding(
                            get: { store.themeMode },
                            set: { v in
                                store.themeMode = v
                                store.invoke("updateSetting", args: ["key": "themeMode", "value": v])
                            }
                        )) {
                            Text("跟随系统").tag("system")
                            Text("液态浅色").tag("light")
                            Text("深空暗色").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .liquidGlass(radius: 18)
                }

                // Feature Toggles
                VStack(spacing: 12) {
                    settingToggle("开启 P2P 打洞直连优先（UDP / IPv6 点对点低延迟通道，多通道不限并发）", key: "directLan", value: $store.directLan)
                    Divider().opacity(0.2)
                    settingToggle("手动强制切换至 500Mbps 专线中转通道（适合企业严格防火墙或跨网丢包场景）", key: "forceRelayDefault", value: $store.forceRelayDefault)
                    Divider().opacity(0.2)
                    settingToggle("启用 4:4:4 无损真彩模式（专业设计修图与清晰代码文字零色度采样损失）", key: "enableTrueColor", value: $store.enableTrueColor)
                    Divider().opacity(0.2)
                    settingToggle("启用 HDR 高动态范围色彩增强（自动协同 4:4:4 真彩与宽色域对比度增强）", key: "enableHdr", value: $store.enableHdr)
                    Divider().opacity(0.2)
                    settingToggle("连接后默认展开实时连接通道（P2P/中转）与 Mbps 速率监控面板", key: "showQualityMonitor", value: $store.showQualityMonitor)
                    Divider().opacity(0.2)
                    settingToggle("启用 Apple Silicon VideoToolbox 硬件加速编解码", key: "hwCodec", value: $store.hwCodec)
                    Divider().opacity(0.2)
                    settingToggle("同步传输远程电脑系统声音", key: "enableSound", value: $store.enableSound)
                    Divider().opacity(0.2)
                    settingToggle("开启双向剪贴板与跨端高速文件复制粘贴", key: "enableClipboard", value: $store.enableClipboard)
                }
                .padding(18)
                .liquidGlass(radius: 20)
            }
            .padding(.bottom, 12)
        }
        .scrollContentBackground(.hidden)
    }

    private func presetCard(mode: String, fps: Double, mbps: Double, title: String, desc: String) -> some View {
        let active = Int(store.customFps) == Int(fps) && Int(store.customQuality) == Int(mbps)
        return Button {
            store.imageQuality = mode
            store.customFps = fps
            store.customQuality = mbps
            store.invoke("setQualityPreset", args: ["mode": mode, "fps": fps, "mbps": mbps])
            store.showToast("已切换至：\(title) · \(Int(mbps))Mbps")
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(active ? Color.cyan : Color.primary)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(active ? Color.cyan.opacity(0.15) : Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(active ? Color.cyan.opacity(0.6) : Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func settingToggle(_ label: String, key: String, value: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13.5, weight: .medium))
            Spacer()
            Toggle("", isOn: Binding(
                get: { value.wrappedValue },
                set: { newVal in
                    value.wrappedValue = newVal
                    store.invoke("updateSetting", args: ["key": key, "value": newVal])
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }
}

// MARK: - Page 5: Temporary Manual Assist & High-Speed Port Forwarding

struct BbsManualAssistPage: View {
    @ObservedObject var store: BbsNativeStore
    @State private var remoteId: String = ""
    @State private var remotePass: String = ""
    @State private var manualForceRelay: Bool = false
    @State private var revealTempCode: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("临时协助与高速端口映射")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("支持输入任意识别码发起远程控制、高速文件传输、TCP 端口映射隧道，并可手动指定专线中转")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)

            HStack(alignment: .top, spacing: 16) {
                // Outgoing Manual Connect Card
                VStack(alignment: .leading, spacing: 14) {
                    Label("发起连接 / 端口映射隧道", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 16, weight: .bold))

                    TextField("输入对方 9 位设备识别码", text: $remoteId)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.24), lineWidth: 1))
                        )

                    SecureField("输入对方临时密码（选填）", text: $remotePass)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.24), lineWidth: 1))
                        )

                    Toggle("本次手动强制走 500Mbps 专线中转通道（Relay）", isOn: $manualForceRelay)
                        .toggleStyle(.switch)
                        .font(.system(size: 12.5, weight: .medium))

                    HStack(spacing: 8) {
                        BbsLiquidActionButton(title: "发起远控", symbol: "play.fill", prominent: true, compact: true) {
                            store.invoke("manualConnect", args: [
                                "id": remoteId,
                                "password": remotePass,
                                "isFileTransfer": false,
                                "forceRelay": manualForceRelay
                            ]) { resp in
                                if (resp["ok"] as? Bool) == false, let err = resp["error"] as? String {
                                    store.showToast(err)
                                }
                            }
                        }
                        BbsLiquidActionButton(title: "传文件", symbol: "folder", prominent: false, compact: true) {
                            store.invoke("manualConnect", args: [
                                "id": remoteId,
                                "password": remotePass,
                                "isFileTransfer": true,
                                "forceRelay": manualForceRelay
                            ])
                        }
                        BbsLiquidActionButton(title: "端口映射隧道", symbol: "network", prominent: false, compact: true) {
                            store.invoke("manualConnect", args: [
                                "id": remoteId,
                                "password": remotePass,
                                "isTcpTunneling": true,
                                "forceRelay": manualForceRelay
                            ])
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity)
                .liquidGlass(radius: 22)

                // Local Temporary Code Card
                VStack(alignment: .leading, spacing: 14) {
                    Label("本机临时被控凭证", systemImage: "lock.shield.fill")
                        .font(.system(size: 16, weight: .bold))

                    Text("仅在需要他人临时协助本机时告知对方，自己名下设备无需此密码：")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("本机识别码：")
                                .foregroundStyle(.secondary)
                            Text(store.formattedMyId)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                        }

                        HStack {
                            Text("临时验证码：")
                                .foregroundStyle(.secondary)
                            Text(revealTempCode ? store.tempPass : "••••••••")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(.cyan)
                            Button {
                                revealTempCode.toggle()
                            } label: {
                                Image(systemName: revealTempCode ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)

                            Button {
                                store.invoke("refreshTempPass")
                                store.showToast("已刷新本机临时验证码")
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("刷新临时验证码")
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )

                    BbsLiquidActionButton(title: "一键复制本机识别码与验证码", symbol: "doc.on.doc", prominent: false) {
                        let text = "BBS-Remote 识别码: \(store.formattedMyId)\n临时验证码: \(store.tempPass)"
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        store.showToast("已复制本机临时协助信息")
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity)
                .liquidGlass(radius: 22)
            }

            Spacer()
        }
    }
}

// MARK: - Page 6: Multi-Screen, Virtual/Wireless/Super Display & Privacy Screen

struct BbsMultiScreenPrivacyPage: View {
    @ObservedObject var store: BbsNativeStore

    private var remotePeers: [BbsDeviceItem] {
        store.devices.filter { !$0.isSelf }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("多屏扩展与隐私防窥中心")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("全员满血解锁：多屏控多屏 · 无线副屏 · 虚拟屏 · 超级屏 · 黑屏防窥与自定义隐私屏保")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)

                // Card 1: Multi-Screen / Virtual Display / Super Screen
                VStack(alignment: .leading, spacing: 12) {
                    Label("多屏控多屏 · 虚拟屏 · 超级屏引擎", systemImage: "rectangle.3.group.fill")
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(.cyan)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("多屏控多屏（所有远端显示器独立全屏窗口同开）")
                                .font(.system(size: 13.5, weight: .semibold))
                            Text("连接多显示器电脑时，自动将对方的多块屏幕分别映射到您本机的多个物理显示器上")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { store.multiScreenAllWindows },
                            set: { val in
                                store.multiScreenAllWindows = val
                                store.invoke("updateSetting", args: ["key": "multiScreenAllWindows", "value": val])
                                store.showToast(val ? "已开启多屏控多屏独立窗口映射" : "已切换为单窗口多屏切换")
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    Divider().opacity(0.22)

                    HStack(spacing: 10) {
                        featurePill("多通道并发", "不限通道数 · 同时远控多台电脑", "square.stack.3d.up.fill")
                        featurePill("虚拟屏扩展", "远控顶部「显示」菜单一键挂载虚拟屏", "display.2")
                        featurePill("超级屏原画", "一键切 4K / 21:9 带鱼屏 / Retina", "arrow.up.left.and.arrow.down.right")
                    }
                }
                .padding(18)
                .liquidGlass(radius: 20)

                // Card 2: Privacy Blackout & Custom Privacy Screensaver
                VStack(alignment: .leading, spacing: 12) {
                    Label("黑屏隐私屏 · 自定义隐私屏保（本机被控时防偷窥）", systemImage: "eye.slash.circle.fill")
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(.indigo)

                    Text("当远程会话顶部「显示 → 隐私模式」开启时，本机物理显示器将立即隐藏真实桌面并锁定本地键鼠，而主控端依然正常流畅操控：")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Picker("", selection: Binding(
                        get: { store.privacyStyle },
                        set: { val in
                            store.privacyStyle = val
                            store.invoke("updateSetting", args: ["key": "privacyStyle", "value": val])
                            store.showToast(val == "screensaver" ? "已切换为自定义隐私屏保模式" : "已切换为纯黑屏防窥模式")
                        }
                    )) {
                        Text("黑屏隐私屏（物理显示器纯黑防窥）").tag("blackout")
                        Text("自定义隐私屏保（物理屏显示专属维护锁屏，主控端正常看桌面）").tag("screensaver")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if store.privacyStyle == "screensaver" {
                        HStack(spacing: 10) {
                            TextField("输入物理显示器上显示的隐私屏保文案...", text: $store.privacyText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13.5))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.primary.opacity(0.05))
                                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.24), lineWidth: 1))
                                )

                            BbsLiquidActionButton(title: "保存屏保文案", symbol: "checkmark", compact: true) {
                                store.invoke("updateSetting", args: ["key": "privacyText", "value": store.privacyText])
                                store.showToast("已保存自定义隐私屏保文案")
                            }
                        }
                    }
                }
                .padding(18)
                .liquidGlass(radius: 20)

                // Card 3: Wireless Secondary Screen & High-Speed Port Forward Quick Launcher
                VStack(alignment: .leading, spacing: 12) {
                    Label("无线副屏 & 端口映射高速中转快速通道", systemImage: "airplayvideo")
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(.cyan)

                    if remotePeers.isEmpty {
                        Text("在另一台 Mac 或 Windows 登录同一账号后，即可在此一键开启无线副屏或高速端口映射隧道")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(remotePeers) { dev in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(dev.online ? Color.green : Color.gray.opacity(0.5))
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dev.displayName)
                                        .font(.system(size: 13.5, weight: .bold))
                                    Text("\(dev.platform.isEmpty ? "Desktop" : dev.platform) · ID: \(dev.formattedId)")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                BbsLiquidActionButton(title: "手动切中转", symbol: "arrow.triangle.branch", prominent: false, compact: true) {
                                    store.connectPeer(dev, forceRelay: true)
                                }
                                BbsLiquidActionButton(title: "端口映射", symbol: "network", prominent: false, compact: true) {
                                    store.connectPeer(dev, portForward: true)
                                }
                                BbsLiquidActionButton(title: "无线副屏", symbol: "display.2", prominent: true, compact: true) {
                                    store.connectPeer(dev, wirelessExt: true)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.primary.opacity(0.04))
                            )
                        }
                    }
                }
                .padding(18)
                .liquidGlass(radius: 20)
            }
            .padding(.bottom, 12)
        }
        .scrollContentBackground(.hidden)
    }

    private func featurePill(_ title: String, _ desc: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(.cyan)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            Text(desc)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        )
    }
}
