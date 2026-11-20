import Cocoa
import FlutterMacOS
import SwiftUI

// MARK: - Data Models

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

enum BbsNavTab: Int, CaseIterable, Identifiable, Hashable {
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

    var subtitle: String {
        switch self {
        case .devices: return "多通道不限并发 · 一键免密直连"
        case .multiscreen: return "多屏控多屏 · 无线副屏 · 虚拟屏 · 隐私屏保"
        case .keymap: return "Mac ⇄ Windows 双向实时映射引擎"
        case .permissions: return "macOS 屏幕录制、辅助功能与后台守护"
        case .settings: return "4K 原画 · 400Hz · 500Mbps · 真彩与 HDR"
        case .assist: return "临时远程协助与 TCP 高速端口映射隧道"
        }
    }

    var symbol: String {
        switch self {
        case .devices: return "laptopcomputer.and.iphone"
        case .multiscreen: return "sparkles.tv"
        case .keymap: return "keyboard"
        case .permissions: return "checkmark.shield"
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

    @Published var selectedTab: BbsNavTab? = .devices
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

    // Key Mappings (544+ Mac & Windows)
    @Published var keyMasterEnabled: Bool = true
    @Published var activeKeyPreset: String = "smart_office"
    @Published var keyTotalCount: Int = 544
    @Published var keyEnabledCount: Int = 0
    @Published var keyPresets: [BbsKeyPresetItem] = []
    @Published var keyOptions: [BbsKeyOptionItem] = []
    @Published var keyRules: [BbsKeyRuleItem] = []

    // UI transient state
    @Published var loginInputUser: String = ""
    @Published var loginInputPass: String = ""
    @Published var loggingIn: Bool = false
    @Published var loginError: String = ""
    @Published var toastMessage: String = ""
    @Published var deviceSearchText: String = ""
    @Published var keySearchText: String = ""
    @Published var showingAddKeyModal: Bool = false

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

    func applyAppAppearance(_ mode: String) {
        DispatchQueue.main.async {
            switch mode {
            case "light":
                NSApp.appearance = NSAppearance(named: .aqua)
            case "dark":
                NSApp.appearance = NSAppearance(named: .darkAqua)
            default:
                NSApp.appearance = nil
            }
        }
    }

    func showToast(_ msg: String) {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                self.toastMessage = msg
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
                guard let self = self, self.toastMessage == msg else { return }
                withAnimation(.easeOut(duration: 0.22)) {
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
                    self.showToast("登录成功 · 已绑定本机免密直连")
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
            showToast("正在打开 TCP 端口映射高速隧道...")
        } else if fileTransfer {
            showToast("正在打开高速文件传输...")
        } else if wirelessExt {
            showToast("正在启动 144Hz 无线扩展副屏...")
        } else if forceRelay || forceRelayDefault {
            showToast("正在通过 500Mbps 专线中转连接...")
        } else {
            showToast("正在建立 P2P 高速直连...")
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
                self.imageQuality = (s["imageQuality"] as? String) ?? "custom"
                if let fps = s["customFps"] as? NSNumber {
                    self.customFps = fps.doubleValue
                }
                if let qual = s["customQuality"] as? NSNumber {
                    self.customQuality = qual.doubleValue
                }
                self.codecPref = (s["codecPref"] as? String) ?? "auto"
                self.viewStyle = (s["viewStyle"] as? String) ?? "original"
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
                let tm = (s["themeMode"] as? String) ?? "system"
                if tm != self.themeMode {
                    self.themeMode = tm
                    self.applyAppAppearance(tm)
                }
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

// MARK: - Authentic Apple macOS 26 Tahoe NSGlassEffectView Surface

/// Uses Apple's real runtime `NSGlassEffectView` on macOS 26+ (Tahoe Liquid Glass),
/// with automatic native `NSVisualEffectView` fallback on macOS 13–15.
struct BbsNativeGlassBackground: NSViewRepresentable {
    var cornerRadius: CGFloat = 18
    var tint: NSColor? = nil

    func makeNSView(context: Context) -> NSView {
        if let glassClass = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let view = glassClass.init(frame: .zero)
            view.setValue(cornerRadius, forKey: "cornerRadius")
            if let tint = tint {
                view.setValue(tint, forKey: "tintColor")
            }
            return view
        }
        let vev = NSVisualEffectView(frame: .zero)
        vev.material = .hudWindow
        vev.blendingMode = .withinWindow
        vev.state = .active
        vev.wantsLayer = true
        vev.layer?.cornerRadius = cornerRadius
        vev.layer?.masksToBounds = true
        return vev
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if NSStringFromClass(type(of: nsView)) == "NSGlassEffectView" {
            nsView.setValue(cornerRadius, forKey: "cornerRadius")
            nsView.setValue(tint, forKey: "tintColor")
        } else {
            nsView.layer?.cornerRadius = cornerRadius
        }
    }
}

extension View {
    /// Floating Liquid Glass surface (for floating HUD pills / toasts) using Apple's runtime NSGlassEffectView.
    func appleGlassCard(radius: CGFloat = 18, tint: NSColor? = nil) -> some View {
        self
            .background(
                BbsNativeGlassBackground(cornerRadius: radius, tint: tint)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75)
            )
    }

    /// Native macOS 26 Tahoe content-layer card surface (auto adapts to Light & Dark Mode, 120fps ScrollView).
    func appleSurfaceCard(radius: CGFloat = 16) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.09), lineWidth: 0.75)
            )
    }
}

// MARK: - Root Container View

struct BbsLiquidGlassRootView: View {
    @ObservedObject var store: BbsNativeStore

    var body: some View {
        ZStack(alignment: .bottom) {
            if !store.isLogin {
                BbsNativeLoginView(store: store)
            } else {
                BbsNativeSplitWorkspaceView(store: store)
            }

            if !store.toastMessage.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                    Text(store.toastMessage)
                        .font(.callout.weight(.medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .appleGlassCard(radius: 22)
                .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
                .padding(.bottom, 18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 1. Native macOS Login View

struct BbsNativeLoginView: View {
    @ObservedObject var store: BbsNativeStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 4)

                VStack(spacing: 4) {
                    Text("BBS-Remote")
                        .font(.title.bold())
                    Text("登录专属账号，一键免密高速远控")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    TextField("管理员分配的专属账号", text: $store.loginInputUser)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                        .onSubmit { store.performLogin() }

                    SecureField("登录密码", text: $store.loginInputPass)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                        .onSubmit { store.performLogin() }
                }

                if !store.loginError.isEmpty {
                    Label(store.loginError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: { store.performLogin() }) {
                    HStack(spacing: 6) {
                        if store.loggingIn {
                            ProgressView().controlSize(.small)
                        }
                        Text(store.loggingIn ? "正在认证..." : "立即登录并绑定本机")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.loggingIn)

                HStack(spacing: 6) {
                    Circle()
                        .fill(store.svcReady ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(store.svcReady ? "专线与 P2P 通道就绪 · 本机 ID \(store.formattedMyId)" : "正在连接节点...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .frame(width: 380)
            .appleSurfaceCard(radius: 24)
            .shadow(color: .black.opacity(0.14), radius: 22, y: 10)

            Spacer()

            if store.isDmgVolume {
                BbsDmgBannerView(store: store)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("BBS-Remote")
        .navigationSubtitle("")
    }
}

// MARK: - 2. Authentic Native macOS 26 Tahoe NavigationSplitView Workspace

struct BbsNativeSplitWorkspaceView: View {
    @ObservedObject var store: BbsNativeStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var activeTab: BbsNavTab {
        store.selectedTab ?? .devices
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $store.selectedTab) {
                Section("远程控制") {
                    Label("我的设备", systemImage: BbsNavTab.devices.symbol)
                        .badge(store.devices.isEmpty ? 0 : store.onlineDeviceCount)
                        .tag(BbsNavTab.devices)

                    Label("多屏与隐私", systemImage: BbsNavTab.multiscreen.symbol)
                        .tag(BbsNavTab.multiscreen)

                    Label("按键映射", systemImage: BbsNavTab.keymap.symbol)
                        .badge(store.keyTotalCount)
                        .tag(BbsNavTab.keymap)
                }

                Section("系统与网络") {
                    Label("本机权限", systemImage: BbsNavTab.permissions.symbol)
                        .badge(store.needsCorePermissions ? "待开启" : "就绪")
                        .tag(BbsNavTab.permissions)

                    Label("设置中心", systemImage: BbsNavTab.settings.symbol)
                        .tag(BbsNavTab.settings)

                    Label("协助与端口", systemImage: BbsNavTab.assist.symbol)
                        .tag(BbsNavTab.assist)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 224, max: 260)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    HStack(spacing: 8) {
                        Image(nsImage: NSApplication.shared.applicationIconImage)
                            .resizable()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(store.displayName.isEmpty ? store.userName : store.displayName)
                                .font(.callout.weight(.semibold))
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(store.svcReady ? Color.green : Color.orange)
                                    .frame(width: 6, height: 6)
                                Text(store.formattedMyId)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(store.myId, forType: .string)
                            store.showToast("已复制本机 ID：\(store.formattedMyId)")
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("复制本机 ID")

                        Button {
                            store.invoke("logout")
                            store.showToast("已退出登录")
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                        .buttonStyle(.borderless)
                        .help("退出登录")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
        } detail: {
            Group {
                switch activeTab {
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
            .navigationTitle(activeTab.title)
            .navigationSubtitle(activeTab.subtitle)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if activeTab == .devices {
                        Button {
                            store.invoke("refreshDevices")
                            store.showToast("已刷新设备在线状态")
                        } label: {
                            Label("刷新设备", systemImage: "arrow.clockwise")
                        }
                        .help("刷新在线设备")
                    } else if activeTab == .keymap {
                        Button {
                            store.showingAddKeyModal = true
                        } label: {
                            Label("新增映射", systemImage: "plus")
                        }
                        .help("新增自定义按键映射")
                    }

                    Menu {
                        Button {
                            store.forceRelayDefault = false
                            store.invoke("updateSetting", args: ["key": "forceRelayDefault", "value": false])
                            store.showToast("已切换为 P2P 智能直连优先")
                        } label: {
                            Label("P2P 智能直连优先", systemImage: store.forceRelayDefault ? "" : "checkmark")
                        }
                        Button {
                            store.forceRelayDefault = true
                            store.invoke("updateSetting", args: ["key": "forceRelayDefault", "value": true])
                            store.showToast("已切换为全局 500Mbps 专线中转")
                        } label: {
                            Label("手动强制 500Mbps 专线中转", systemImage: store.forceRelayDefault ? "checkmark" : "")
                        }
                    } label: {
                        Label(
                            store.forceRelayDefault ? "专线中转" : "P2P 直连",
                            systemImage: store.forceRelayDefault ? "arrow.triangle.branch" : "bolt.horizontal.fill"
                        )
                    }
                    .help("切换默认连接通道（P2P 直连 / 手动中转）")
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Banners

struct BbsDmgBannerView: View {
    @ObservedObject var store: BbsNativeStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.app.fill")
                .font(.title3)
                .foregroundStyle(.tint)
            Text("当前正在磁盘映像内运行，建议移入「应用程序」以保持系统权限持久有效")
                .font(.callout)
            Spacer()
            Button("一键安装到应用程序") {
                store.invoke("installToApps")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .appleSurfaceCard(radius: 14)
    }
}

struct BbsPermQuickBanner: View {
    @ObservedObject var store: BbsNativeStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)
            Text("本机尚未开启屏幕录制或辅助功能权限，其他设备远控本机时可能无法看到画面或操作鼠标")
                .font(.callout)
                .lineLimit(2)
            Spacer()
            Button("去开启") {
                store.selectedTab = .permissions
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                store.invoke("dismissPermBanner")
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .appleSurfaceCard(radius: 14)
    }
}

// MARK: - Page 1: My Devices (Responsive Adaptive Grid + Native Liquid Glass Cards)

struct BbsMyDevicesPage: View {
    @ObservedObject var store: BbsNativeStore
    @State private var renamingDevice: BbsDeviceItem?
    @State private var renameText: String = ""
    @State private var deletingDevice: BbsDeviceItem?

    private var filteredDevices: [BbsDeviceItem] {
        let q = store.deviceSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sorted = store.devices.sorted { a, b in
            if a.isSelf != b.isSelf { return !a.isSelf }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if store.isDmgVolume {
                    BbsDmgBannerView(store: store)
                }
                if store.needsCorePermissions && !store.permDismissed {
                    BbsPermQuickBanner(store: store)
                }

                // Local Host Summary Glass Card
                HStack(spacing: 14) {
                    Image(systemName: "desktopcomputer")
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .frame(width: 42, height: 42)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(store.myHostname.isEmpty ? "当前 Mac" : store.myHostname)
                                .font(.headline)
                            Text("本机")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.14), in: Capsule())
                                .foregroundStyle(.tint)
                            if store.videoConnCount > 0 {
                                Text("远控连接中 (\(store.videoConnCount))")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.16), in: Capsule())
                                    .foregroundStyle(.green)
                            }
                        }
                        Text("识别码 \(store.formattedMyId) · 4K 400Hz · 500Mbps · 多通道免密被控就绪")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(store.myId, forType: .string)
                        store.showToast("已复制本机 ID：\(store.formattedMyId)")
                    } label: {
                        Label("复制 ID", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                .padding(14)
                .appleSurfaceCard(radius: 16)

                // Responsive Device Grid (adapts smoothly to 1, 2, or 3 columns!)
                if filteredDevices.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "laptopcomputer.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("暂无匹配的设备")
                            .font(.headline)
                        Text("在另一台 Mac 或 Windows 登录同一账号，即可在此一键免密远控")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 64)
                    .appleSurfaceCard(radius: 18)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 320, maximum: 540), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(filteredDevices) { dev in
                            BbsDeviceGlassCard(
                                dev: dev,
                                onConnect: { store.connectPeer(dev) },
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
                }
            }
            .padding(18)
        }
        .searchable(text: $store.deviceSearchText, placement: .toolbar, prompt: "搜索设备名称或 ID")
        .sheet(item: $renamingDevice) { dev in
            VStack(alignment: .leading, spacing: 14) {
                Text("修改设备备注名称").font(.headline)
                TextField("如：办公室 MacBook Pro / 家里主力机", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                HStack {
                    Spacer()
                    Button("取消") { renamingDevice = nil }
                    Button("保存") {
                        store.invoke("renamePeer", args: ["id": dev.id, "alias": renameText])
                        store.showToast("已更新设备备注")
                        renamingDevice = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
        }
        .sheet(item: $deletingDevice) { dev in
            VStack(alignment: .leading, spacing: 14) {
                Text("移除绑定设备").font(.headline)
                Text("确定从设备列表移除「\(dev.displayName)」吗？")
                    .foregroundStyle(.secondary)
                    .frame(width: 300, alignment: .leading)
                HStack {
                    Spacer()
                    Button("取消") { deletingDevice = nil }
                    Button("移除", role: .destructive) {
                        store.invoke("deletePeer", args: ["id": dev.id])
                        store.showToast("已移除设备")
                        deletingDevice = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
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

    private var platformIcon: String {
        let p = dev.platform.lowercased()
        if p.contains("mac") || p.contains("darwin") { return "laptopcomputer" }
        if p.contains("win") { return "pc" }
        if p.contains("android") || p.contains("ios") { return "iphone" }
        return "desktopcomputer"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: platformIcon)
                    .font(.title2)
                    .foregroundStyle(dev.online ? Color.accentColor : Color.secondary)
                    .frame(width: 40, height: 40)
                    .background(
                        (dev.online ? Color.accentColor : Color.secondary).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(dev.displayName)
                            .font(.headline)
                            .lineLimit(1)
                        if dev.isSelf {
                            Text("本机")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.14), in: Capsule())
                                .foregroundStyle(.tint)
                        }
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(dev.online ? Color.green : Color.gray.opacity(0.5))
                            .frame(width: 7, height: 7)
                        Text(dev.online ? "在线" : "离线")
                            .font(.caption)
                            .foregroundStyle(dev.online ? Color.green : Color.secondary)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(dev.platform.isEmpty ? "Desktop" : dev.platform)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(dev.formattedId.isEmpty ? dev.id : dev.formattedId)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

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
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Divider()

            HStack(spacing: 8) {
                if !dev.isSelf {
                    Button(action: onTransfer) {
                        Label("传文件", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .fixedSize()

                    Button(action: onPortForward) {
                        Label("端口映射", systemImage: "network")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .fixedSize()

                    Spacer(minLength: 4)

                    Button(action: onConnect) {
                        Label("一键远程", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .fixedSize()
                } else {
                    Text("当前主控端 · 多通道并发已解锁")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(14)
        .appleSurfaceCard(radius: 16)
    }
}

// MARK: - Page 2: Multi-Screen, Virtual/Wireless/Super Display & Privacy (Native Grouped Form)

struct BbsMultiScreenPrivacyPage: View {
    @ObservedObject var store: BbsNativeStore

    private var remotePeers: [BbsDeviceItem] {
        store.devices.filter { !$0.isSelf }
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { store.multiScreenAllWindows },
                    set: { val in
                        store.multiScreenAllWindows = val
                        store.invoke("updateSetting", args: ["key": "multiScreenAllWindows", "value": val])
                        store.showToast(val ? "已开启多屏控多屏" : "已切换为单窗口多屏切换")
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("多屏控多屏（所有远端屏幕独立窗口同开）")
                        Text("连接多显示器电脑时，自动将远端多块屏幕映射到本机多显示器上")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("虚拟屏与超级屏") {
                    Text("远控顶部「显示 → 尊享旗舰画质 · 中转 · 超级屏」一键挂载虚拟屏或切 4K / 21:9 带鱼屏")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("多屏控多屏 · 虚拟屏 · 超级屏")
            }

            Section {
                Picker("隐私防窥呈现方式", selection: Binding(
                    get: { store.privacyStyle },
                    set: { val in
                        store.privacyStyle = val
                        store.invoke("updateSetting", args: ["key": "privacyStyle", "value": val])
                        store.showToast(val == "screensaver" ? "已切换为自定义隐私屏保模式" : "已切换为纯黑屏防窥模式")
                    }
                )) {
                    Text("黑屏隐私屏（物理显示器纯黑防窥并锁本地键鼠）").tag("blackout")
                    Text("自定义隐私屏保（物理屏显示专属锁屏，主控端正常看桌面）").tag("screensaver")
                }
                .pickerStyle(.radioGroup)

                if store.privacyStyle == "screensaver" {
                    HStack(spacing: 8) {
                        TextField("自定义隐私屏保提示文案", text: $store.privacyText)
                            .textFieldStyle(.roundedBorder)
                        Button("保存文案") {
                            store.invoke("updateSetting", args: ["key": "privacyText", "value": store.privacyText])
                            store.showToast("已保存自定义隐私屏保文案")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            } header: {
                Text("黑屏隐私屏与自定义隐私屏保")
            } footer: {
                Text("在远控顶部菜单点击「显示 → 隐私模式」即可实时触发，采用 macOS NSWindowSharingNone 原生防录屏层，主控端不受遮挡。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("无线副屏 · 手动切中转 · 端口映射快启") {
                if remotePeers.isEmpty {
                    Text("在另一台电脑登录同一账号后，即可在此一键以无线副屏或端口映射方式连接")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(remotePeers) { dev in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(dev.online ? Color.green : Color.gray.opacity(0.5))
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dev.displayName).font(.body.weight(.medium))
                                Text("\(dev.platform.isEmpty ? "Desktop" : dev.platform) · \(dev.formattedId)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("切中转") {
                                store.connectPeer(dev, forceRelay: true)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("端口映射") {
                                store.connectPeer(dev, portForward: true)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("无线副屏") {
                                store.connectPeer(dev, wirelessExt: true)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Page 3: Key Mapping Center (544+ Mac & Windows Mappings)

struct BbsKeyMappingPage: View {
    @ObservedObject var store: BbsNativeStore
    @State private var categoryFilter: String = "all"
    @State private var peerFilter: String = "all"

    private var filteredRules: [BbsKeyRuleItem] {
        let q = store.keySearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
        VStack(spacing: 0) {
            // Top Controls Bar (100% responsive, zero horizontal overflow)
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { store.keyMasterEnabled },
                        set: { val in
                            store.keyMasterEnabled = val
                            store.invoke("setKeyMasterEnabled", args: ["enabled": val])
                            store.showToast(val ? "已启用全局按键映射引擎" : "已暂停按键映射")
                        }
                    )) {
                        Text("全局按键映射引擎（内置 \(store.keyTotalCount) 项 · 已启用 \(store.keyEnabledCount) 项）")
                            .font(.callout.weight(.semibold))
                    }
                    .toggleStyle(.switch)

                    Spacer()

                    Picker("场景预设", selection: Binding(
                        get: { store.activeKeyPreset },
                        set: { val in
                            store.activeKeyPreset = val
                            store.invoke("applyKeyPreset", args: ["presetId": val])
                            if let p = store.keyPresets.first(where: { $0.id == val }) {
                                store.showToast("已切换方案：\(p.name)")
                            }
                        }
                    )) {
                        ForEach(store.keyPresets) { p in
                            Text(p.name).tag(p.id)
                        }
                    }
                    .frame(maxWidth: 230)
                }

                HStack(spacing: 10) {
                    Picker("分类", selection: $categoryFilter) {
                        Text("全部分类").tag("all")
                        Text("系统互转").tag("system")
                        Text("办公 / 浏览器").tag("office")
                        Text("开发 / 设计 / 3D").tag("creative")
                        Text("电竞 / 游戏").tag("gaming")
                        Text("我的自定义").tag("custom")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Picker("远端系统", selection: $peerFilter) {
                        Text("全部系统").tag("all")
                        Text("远端 Win").tag("windows")
                        Text("远端 Mac").tag("macos")
                        Text("仅已启用").tag("enabled")
                    }
                    .labelsHidden()
                    .frame(width: 112)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                if filteredRules.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("未找到匹配的按键映射")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredRules) { rule in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(rule.direction)
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.14), in: Capsule())
                                            .foregroundStyle(.tint)
                                        Text(rule.name)
                                            .font(.callout.weight(.medium))
                                            .lineLimit(1)
                                    }
                                    Text("\(rule.subGroup) · \(rule.desc)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 8)

                                Text(rule.srcDisplay)
                                    .font(.caption.monospaced().weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .fixedSize()

                                Image(systemName: "arrow.right")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)

                                Text(rule.dstDisplay)
                                    .font(.caption.monospaced().weight(.semibold))
                                    .foregroundStyle(.tint)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .fixedSize()

                                if rule.isCustom {
                                    Button(role: .destructive) {
                                        store.invoke("deleteCustomKeyRule", args: ["id": rule.id])
                                        store.showToast("已删除自定义映射")
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }

                                Toggle("", isOn: Binding(
                                    get: { rule.enabled },
                                    set: { val in store.toggleRuleOptimistic(rule.id, enabled: val) }
                                ))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .appleSurfaceCard(radius: 12)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .searchable(text: $store.keySearchText, placement: .toolbar, prompt: "搜索 540+ 快捷键（复制、截图、VS Code、PS、Blender、原神、FPS、LOL...）")
        .sheet(isPresented: $store.showingAddKeyModal) {
            BbsAddCustomKeyRuleSheet(store: store, isPresented: $store.showingAddKeyModal)
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
        VStack(alignment: .leading, spacing: 14) {
            Text("新增自定义按键映射").font(.headline)

            Form {
                TextField("规则名称", text: $name)
                Picker("远端系统", selection: $peer) {
                    Text("Mac & Win 通用").tag("all")
                    Text("仅远端 Windows").tag("windows")
                    Text("仅远端 macOS").tag("macos")
                }
                Section("触发键位（本机按下）") {
                    HStack(spacing: 12) {
                        Toggle("⌘ Cmd", isOn: $srcMeta)
                        Toggle("⌃ Ctrl", isOn: $srcCtrl)
                        Toggle("⌥ Opt", isOn: $srcAlt)
                        Toggle("⇧ Shift", isOn: $srcShift)
                    }
                    Picker("主键", selection: $srcKey) {
                        ForEach(sourceKeyChoices) { item in
                            Text(item.label).tag(item.code)
                        }
                    }
                }
                Section("目标键位（发送至远端）") {
                    HStack(spacing: 12) {
                        Toggle("Ctrl", isOn: $dstCtrl)
                        Toggle("Win / Cmd", isOn: $dstMeta)
                        Toggle("Alt / Opt", isOn: $dstAlt)
                        Toggle("Shift", isOn: $dstShift)
                    }
                    Picker("目标键", selection: $dstKey) {
                        ForEach(store.keyOptions) { item in
                            Text(item.label).tag(item.code)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 460, height: 340)

            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                Button("保存并启用") {
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
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
    }
}

// MARK: - Page 4: Permissions (Native macOS System Settings Grouped Form)

struct BbsPermissionsPage: View {
    @ObservedObject var store: BbsNativeStore

    var body: some View {
        Form {
            Section("必需被控权限") {
                permRow(
                    title: "屏幕录制与系统音频",
                    desc: "允许其他设备观看本机 4K 400FPS 桌面画面",
                    granted: store.canScreenRecord,
                    actionTitle: "去开启"
                ) { store.invoke("openPerm", args: ["kind": "screen"]) }

                permRow(
                    title: "辅助功能控制",
                    desc: "允许远端控制本机鼠标键盘（含操控本机 BBS-Remote 窗口）",
                    granted: store.canAccessibility,
                    actionTitle: "去开启"
                ) { store.invoke("openPerm", args: ["kind": "accessibility"]) }
            }

            Section("增强体验权限") {
                permRow(
                    title: "输入监控 (Input Monitoring)",
                    desc: "启用底层低延迟游戏级按键映射抓取",
                    granted: store.canInputMonitor,
                    actionTitle: "去开启"
                ) { store.invoke("openPerm", args: ["kind": "input"]) }

                permRow(
                    title: "后台常驻无人值守服务",
                    desc: "支持锁屏界面自动在线与随时唤醒连接",
                    granted: store.daemonInstalled,
                    actionTitle: "一键安装"
                ) { store.invoke("openPerm", args: ["kind": "daemon"]) }
            }

            Section("权限自愈与重启") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("覆盖升级后卡在「等待画面传输」？")
                            .font(.callout.weight(.medium))
                        Text("一键清理 macOS 旧版签名权限缓存并重新拉起系统授权弹窗")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("重置权限识别") {
                        store.invoke("repairPerms")
                        store.showToast("已重置权限缓存，请在系统窗口中重新开启")
                    }
                    .buttonStyle(.bordered)

                    Button("重启客户端") {
                        store.invoke("relaunchApp")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func permRow(title: String, desc: String, granted: Bool, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Text("已开启")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.14), in: Capsule())
            } else {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }
}

// MARK: - Page 5: Settings Center (Native macOS System Settings Grouped Form)

struct BbsSettingsPage: View {
    @ObservedObject var store: BbsNativeStore

    var body: some View {
        Form {
            Section("画质 · 高刷 · 500Mbps 真码率") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 10)], spacing: 10) {
                    presetBtn(fps: 144, mbps: 500, title: "4K 原画 · 144Hz", sub: "500Mbps 满血")
                    presetBtn(fps: 240, mbps: 300, title: "电竞极速 · 240Hz", sub: "300Mbps 低延迟")
                    presetBtn(fps: 400, mbps: 500, title: "极限超频 · 400Hz", sub: "500Mbps 解锁")
                    presetBtn(fps: 60, mbps: 30, title: "均衡省流 · 60Hz", sub: "30Mbps 流畅")
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("目标帧率上限")
                        Spacer()
                        Text("\(Int(store.customFps)) FPS")
                            .font(.callout.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                    Slider(value: $store.customFps, in: 30...400, step: 10) { editing in
                        if !editing {
                            store.invoke("updateSetting", args: ["key": "customFps", "value": store.customFps])
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("自定义码率上限")
                        Spacer()
                        Text("\(Int(store.customQuality)) Mbps")
                            .font(.callout.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                    Slider(value: $store.customQuality, in: 5...500, step: 5) { editing in
                        if !editing {
                            store.invoke("updateSetting", args: ["key": "customQuality", "value": store.customQuality])
                        }
                    }
                }
            }

            Section("色彩 · 编解码 · 外观") {
                Picker("视频硬件编码器", selection: Binding(
                    get: { store.codecPref },
                    set: { v in
                        store.codecPref = v
                        store.invoke("updateSetting", args: ["key": "codecPref", "value": v])
                    }
                )) {
                    Text("自动").tag("auto")
                    Text("H.265").tag("h265")
                    Text("H.264").tag("h264")
                    Text("AV1").tag("av1")
                }
                .pickerStyle(.segmented)

                Picker("界面外观", selection: Binding(
                    get: { store.themeMode },
                    set: { v in
                        store.themeMode = v
                        store.applyAppAppearance(v)
                        store.invoke("updateSetting", args: ["key": "themeMode", "value": v])
                    }
                )) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.segmented)

                settingToggle("4:4:4 无损真彩模式", sub: "适合设计修图与清晰代码文字显示", key: "enableTrueColor", value: $store.enableTrueColor)
                settingToggle("HDR 高动态范围色彩增强", sub: "宽色域对比度增强并自动协同 4:4:4 真彩", key: "enableHdr", value: $store.enableHdr)
                settingToggle("VideoToolbox 硬件加速", sub: "调用 Apple Silicon 媒体引擎超低功耗编解码", key: "hwCodec", value: $store.hwCodec)
            }

            Section("连接通道与互动") {
                settingToggle("P2P 打洞直连优先", sub: "UDP / IPv6 点对点直连，多通道不限并发", key: "directLan", value: $store.directLan)
                settingToggle("全局手动强制 500Mbps 专线中转", sub: "跨运营商抖动或严格防火墙下强制走高速中转", key: "forceRelayDefault", value: $store.forceRelayDefault)
                settingToggle("默认展开连接通道与 Mbps 速率监控", sub: "会话画面右上角实时显示 P2P/中转 与 Mbps", key: "showQualityMonitor", value: $store.showQualityMonitor)
                settingToggle("远程系统声音同步", sub: "同步回传远端电脑音频", key: "enableSound", value: $store.enableSound)
                settingToggle("双向剪贴板与跨端文件复制粘贴", sub: "支持文本、图片与文件跨设备直接复制粘贴", key: "enableClipboard", value: $store.enableClipboard)
            }
        }
        .formStyle(.grouped)
    }

    private func presetBtn(fps: Double, mbps: Double, title: String, sub: String) -> some View {
        let active = Int(store.customFps) == Int(fps) && Int(store.customQuality) == Int(mbps)
        return Button {
            store.imageQuality = "custom"
            store.customFps = fps
            store.customQuality = mbps
            store.invoke("setQualityPreset", args: ["mode": "custom", "fps": fps, "mbps": mbps])
            store.showToast("已切换至 \(title) · \(Int(mbps))Mbps")
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.callout.weight(.semibold))
                Text(sub).font(.caption).foregroundStyle(active ? Color.accentColor : Color.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(active ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(active ? Color.accentColor : Color.primary.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func settingToggle(_ title: String, sub: String, key: String, value: Binding<Bool>) -> some View {
        Toggle(isOn: Binding(
            get: { value.wrappedValue },
            set: { newVal in
                value.wrappedValue = newVal
                store.invoke("updateSetting", args: ["key": key, "value": newVal])
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(sub).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Page 6: Manual Assist & TCP Port Forwarding

struct BbsManualAssistPage: View {
    @ObservedObject var store: BbsNativeStore
    @State private var remoteId: String = ""
    @State private var remotePass: String = ""
    @State private var manualForceRelay: Bool = false
    @State private var revealTempCode: Bool = false

    var body: some View {
        Form {
            Section("连接外部设备 / TCP 端口映射高速隧道") {
                TextField("对方 9 位设备识别码", text: $remoteId)
                SecureField("对方临时验证码（选填）", text: $remotePass)
                Toggle("本次手动强制走 500Mbps 专线中转通道", isOn: $manualForceRelay)

                HStack(spacing: 10) {
                    Button {
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
                    } label: {
                        Label("发起远控", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        store.invoke("manualConnect", args: [
                            "id": remoteId,
                            "password": remotePass,
                            "isFileTransfer": true,
                            "forceRelay": manualForceRelay
                        ])
                    } label: {
                        Label("高速传文件", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        store.invoke("manualConnect", args: [
                            "id": remoteId,
                            "password": remotePass,
                            "isTcpTunneling": true,
                            "forceRelay": manualForceRelay
                        ])
                    } label: {
                        Label("打开 TCP 端口映射", systemImage: "network")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("本机临时被控凭证") {
                LabeledContent("本机识别码") {
                    Text(store.formattedMyId).font(.body.monospaced().bold())
                }
                LabeledContent("临时验证码") {
                    HStack(spacing: 8) {
                        Text(revealTempCode ? store.tempPass : "••••••••")
                            .font(.body.monospaced().bold())
                        Button {
                            revealTempCode.toggle()
                        } label: {
                            Image(systemName: revealTempCode ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        Button {
                            store.invoke("refreshTempPass")
                            store.showToast("已刷新本机临时验证码")
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button {
                    let text = "BBS-Remote 识别码: \(store.formattedMyId)\n临时验证码: \(store.tempPass)"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    store.showToast("已复制本机临时协助信息")
                } label: {
                    Label("一键复制本机识别码与验证码", systemImage: "doc.on.doc")
                }
            }
        }
        .formStyle(.grouped)
    }
}
