import SwiftUI
import AppKit

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(
                selection: $model.selectedSettingsSection,
                isProtectionActive: model.settings.isProtectionActive,
                theme: $model.settings.interfaceTheme
            )
                .frame(width: 228)
            Group {
                switch model.selectedSettingsSection ?? .overview {
                case .overview: OverviewDashboardView(model: model)
                case .rules: RulesSettingsView(
                    settings: $model.settings,
                    testStatuses: model.ruleTestStatuses,
                    onTest: model.testRule
                )
                case .localNetwork: LocalNetworkMonitorView()
                case .notifications: EmailSettingsView(model: model)
                case .history: RuntimeLogView(model: model)
                case .preferences: PreferencesSettingsView(
                    settings: $model.settings,
                    identity: model.identity,
                    status: model.status
                )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DashboardPalette.canvas)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: SettingsLayoutMetrics.contentCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SettingsLayoutMetrics.contentCornerRadius, style: .continuous)
                    .stroke(DashboardPalette.border, lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.13), radius: 18, x: -3, y: 3)
            .padding(.vertical, 8)
            .padding(.trailing, 8)
        }
        .foregroundStyle(DashboardPalette.text)
        .background(DashboardPalette.sidebar)
        .preferredColorScheme(model.settings.interfaceTheme.colorScheme)
        .id(model.settings.interfaceTheme)
    }
}

private struct SettingsSidebar: View {
    @Binding var selection: SettingsSection?
    let isProtectionActive: Bool
    @Binding var theme: InterfaceTheme
    @State private var visualTheme: InterfaceTheme
    @State private var themeCommitTask: Task<Void, Never>?
    @Namespace private var selectionAnimation

    init(selection: Binding<SettingsSection?>, isProtectionActive: Bool, theme: Binding<InterfaceTheme>) {
        _selection = selection
        self.isProtectionActive = isProtectionActive
        _theme = theme
        _visualTheme = State(initialValue: theme.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text("EgressGuard").font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("出口安全控制台").font(.caption2).foregroundStyle(DashboardPalette.text.opacity(0.48))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)

            VStack(spacing: 5) {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        selectSection(section)
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: section.symbolName)
                                .font(.system(size: 14, weight: .medium)).frame(width: 20)
                            Text(section.title).fontWeight(selection == section ? .semibold : .regular)
                            Spacer()
                        }
                        .foregroundStyle(selection == section ? Color.white : DashboardPalette.text.opacity(0.62))
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background {
                            if selection == section {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(LinearGradient(
                                        colors: [DashboardPalette.coral, DashboardPalette.pink, DashboardPalette.blue],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .shadow(color: DashboardPalette.pink.opacity(0.24), radius: 12, y: 5)
                                    .matchedGeometryEffect(id: "sidebar-selection", in: selectionAnimation)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay {
                GeometryReader { proxy in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let sections = SettingsSection.allCases
                                    guard let index = ContinuousSelection.index(
                                        position: value.location.y,
                                        totalExtent: proxy.size.height,
                                        itemCount: sections.count
                                    ) else { return }
                                    selectSection(sections[index])
                                }
                        )
                }
            }
            .padding(.horizontal, 10)

            Spacer()
            themeSelector
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            HStack(spacing: 8) {
                Circle().fill(isProtectionActive ? .green : .orange).frame(width: 7, height: 7)
                    .shadow(color: (isProtectionActive ? Color.green : Color.orange).opacity(0.8), radius: 5)
                Text(isProtectionActive ? "出口保护已启用" : "出口保护未启用")
                    .font(.caption).foregroundStyle(DashboardPalette.text.opacity(0.48))
            }
            .padding(20)
        }
        .padding(.top, 52)
        .foregroundStyle(DashboardPalette.text)
        .background(
            LinearGradient(colors: [DashboardPalette.sidebar, DashboardPalette.sidebarBottom], startPoint: .top, endPoint: .bottom)
        )
        .background(.ultraThinMaterial)
    }

    private var themeSelector: some View {
        HStack(spacing: 3) {
            ForEach(InterfaceTheme.allCases) { option in
                Button {
                    selectTheme(option)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: option.symbolName)
                        Text(option.title)
                    }
                        .font(.system(size: 10, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .foregroundStyle(visualTheme == option ? Color.white : DashboardPalette.text.opacity(0.62))
                        .background {
                            if visualTheme == option {
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [DashboardPalette.pink, DashboardPalette.blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .matchedGeometryEffect(id: "theme-selection", in: selectionAnimation)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(option.title)
            }
        }
        .overlay {
            GeometryReader { proxy in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let themes = InterfaceTheme.allCases
                                guard let index = ContinuousSelection.index(
                                    position: value.location.x,
                                    totalExtent: proxy.size.width,
                                    itemCount: themes.count
                                ) else { return }
                                selectTheme(themes[index])
                            }
                    )
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(DashboardPalette.border))
        .onDisappear { themeCommitTask?.cancel() }
    }

    private func selectSection(_ section: SettingsSection) {
        guard selection != section else { return }
        withAnimation(.smooth(duration: SettingsLayoutMetrics.selectionAnimationDuration)) {
            selection = section
        }
    }

    private func selectTheme(_ option: InterfaceTheme) {
        guard visualTheme != option else { return }
        withAnimation(.smooth(duration: SettingsLayoutMetrics.selectionAnimationDuration)) {
            visualTheme = option
        }
        themeCommitTask?.cancel()
        themeCommitTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(SettingsLayoutMetrics.themeCommitDelay))
            guard !Task.isCancelled else { return }
            theme = option
        }
    }
}

extension InterfaceTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private struct OverviewDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var model: AppModel

    var body: some View {
        ZStack(alignment: .top) {
            DashboardPalette.canvas
            LinearGradient(
                colors: overviewHeaderColors,
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: SettingsLayoutMetrics.overviewHeaderHeight)
            .overlay(alignment: .trailing) {
                Image(systemName: "network")
                    .font(.system(size: 125, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(colorScheme == .light ? 0.16 : 0.08))
                    .padding(.trailing, 34)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    dashboardHeader
                    metricCards
                    VStack(spacing: 20) {
                        HStack(alignment: .top, spacing: 20) {
                            identityPanel
                            policyPanel.frame(width: 300)
                        }
                        HStack(alignment: .top, spacing: 20) {
                            emailPanel
                            launchAtLoginPanel.frame(width: 300)
                        }
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 40)
                .padding(.bottom, 32)
            }
        }
    }

    private var dashboardHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text("安全概览")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("持续确认这台 Mac 的公网出口身份")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.76))
            }
            Spacer()
            Button { model.checkNow() } label: {
                Label(model.status == .checking ? "检测中" : "立即检测", systemImage: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 15)
                    .frame(height: 38)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
            .disabled(model.status == .checking)
        }
        .frame(height: 72, alignment: .top)
    }

    private var overviewHeaderColors: [Color] {
        if colorScheme == .light {
            return [
                Color(red: 0.34, green: 0.82, blue: 0.76),
                Color(red: 0.27, green: 0.69, blue: 0.91),
                Color(red: 0.38, green: 0.54, blue: 0.94)
            ]
        }
        return [DashboardPalette.coral, DashboardPalette.pink, DashboardPalette.blue]
    }

    private var metricCards: some View {
        HStack(spacing: 18) {
            MetricCard(icon: model.status.symbolName, value: model.status.title,
                       label: model.settings.isProtectionActive ? "出口保护已启用" : "出口保护未启用",
                       colors: [DashboardPalette.coral, DashboardPalette.pink])
            MetricCard(icon: "globe.asia.australia.fill", value: model.identity?.ipv4Address ?? "等待检测",
                       label: model.identity.map { "\($0.countryFlag) \($0.countryName ?? "未知地区")" } ?? "当前公网 IPv4",
                       colors: [DashboardPalette.pink, DashboardPalette.purple])
            MetricCard(icon: "checklist.checked", value: "\(configuredRuleCount)",
                       label: "开启规则数", colors: [DashboardPalette.purple, DashboardPalette.blue])
        }
    }

    private var identityPanel: some View {
        DashboardPanel(title: "当前出口身份", subtitle: identitySubtitle, minimumHeight: 300) {
            VStack(spacing: 0) {
                IdentityRow(icon: "arrow.triangle.branch", title: "代理出口 IPv4", value: model.identity?.ipv4Address ?? "未检测到", tint: DashboardPalette.coral)
                IdentityRow(icon: "point.3.filled.connected.trianglepath.dotted", title: "无系统代理 IPv4", value: model.directIdentity?.ipv4Address ?? "未检测到", tint: DashboardPalette.pink)
                IdentityRow(icon: "building.2", title: "代理网络归属", value: networkOwner, tint: DashboardPalette.purple)
                IdentityRow(icon: "mappin.and.ellipse", title: "代理国家或地区", value: countryDescription, tint: DashboardPalette.blue, showsDivider: false)
            }
        }
    }

    private var emailPanel: some View {
        DashboardPanel(title: "邮件通知", subtitle: emailSubtitle) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DashboardPalette.blue.opacity(0.15))
                    Image(systemName: model.settings.email.isEnabled ? "envelope.badge.fill" : "envelope.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DashboardPalette.blue)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(model.settings.email.isEnabled ? Color.green : DashboardPalette.text.opacity(0.28))
                            .frame(width: 7, height: 7)
                        Text(model.settings.email.isEnabled ? "邮件推送已开启" : "邮件推送未开启")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(model.settings.email.displayAddress)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(DashboardPalette.text.opacity(0.52))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 12)

                Button { model.selectedSettingsSection = .notifications } label: {
                    Label("配置", systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(DashboardPalette.glassFill, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(DashboardPalette.border))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var launchAtLoginPanel: some View {
        DashboardPanel(title: "开机自启动", subtitle: model.launchAtLoginStatus.detail) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DashboardPalette.purple.opacity(0.15))
                    Image(systemName: "power.circle.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(DashboardPalette.purple)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.launchAtLoginStatus.title)
                        .font(.system(size: 14, weight: .semibold))
                    if model.launchAtLoginStatus == .requiresApproval {
                        Button("打开系统设置", action: model.openLoginItemsSettings)
                            .buttonStyle(.link)
                            .font(.caption)
                    }
                }

                Spacer(minLength: 8)
                Toggle("开机自启动", isOn: launchAtLoginBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(model.isUpdatingLaunchAtLogin)
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLoginStatus.isEnabled },
            set: { isEnabled in model.setLaunchAtLoginEnabled(isEnabled) }
        )
    }

    private var policyPanel: some View {
        DashboardPanel(title: "保护策略", subtitle: policySummary, minimumHeight: 300) {
            VStack(alignment: .leading, spacing: 16) {
                Label("每 \(Int(model.settings.checkInterval)) 秒自动检测", systemImage: "timer")
                Label("连续 \(model.settings.violationThreshold) 次规则命中后执行", systemImage: "shield.lefthalf.filled")
                Label("\(configuredRuleCount) 条允许条件", systemImage: "checklist.checked")
                Label("\(model.protectedApplications.count) 个处置目标", systemImage: "square.stack.3d.up")

                Button { model.selectedSettingsSection = .rules } label: {
                    HStack {
                        Text("配置保护规则")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(
                        LinearGradient(colors: [DashboardPalette.coral, DashboardPalette.pink, DashboardPalette.blue], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 13))
            .foregroundStyle(DashboardPalette.text.opacity(0.78))
        }
    }

    private var identitySubtitle: String {
        guard let identity = model.identity else { return "尚未获得检测结果" }
        let state = model.hasSplitEgress
            ? "检测到代理与无代理请求分流"
            : "两个请求出口一致；VPN/TUN 可能隐藏物理直连"
        return "\(state) · \(identity.checkedAt.formatted(date: .omitted, time: .shortened)) 更新"
    }

    private var emailSubtitle: String {
        guard model.settings.email.isComplete else { return "尚未完成 SMTP 与收件邮箱配置" }
        return "IP 变更、规则执行和运行失败时发送告警"
    }

    private var networkOwner: String {
        guard let identity = model.identity else { return "—" }
        let value = [identity.asn, identity.organization].compactMap { $0 }.joined(separator: " · ")
        return value.isEmpty ? "未知" : value
    }

    private var countryDescription: String {
        guard let identity = model.identity else { return "—" }
        return "\(identity.countryFlag) \(identity.countryName ?? identity.countryCode ?? "未知")"
    }

    private var configuredRuleCount: Int {
        if !model.settings.rules.isEmpty {
            return model.settings.rules.filter(\.isEnabled).count
        }
        return model.settings.allowedIPs.count + model.settings.allowedCIDRs.count + model.settings.allowedCountryCodes.count + model.settings.allowedASNs.count
    }

    private var policySummary: String {
        model.policyMessage ?? (model.settings.hasPolicyConstraints ? "规则已就绪" : "尚未配置允许条件")
    }
}

private struct MetricCard: View {
    let icon: String
    let value: String
    let label: String
    let colors: [Color]

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle().fill(LinearGradient(colors: colors.map { $0.opacity(0.42) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().stroke(DashboardPalette.border)
                Image(systemName: icon).font(.system(size: 22, weight: .medium))
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.system(size: 20, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                Text(label).font(.caption).foregroundStyle(DashboardPalette.text.opacity(0.55)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 92)
        .background(
            LinearGradient(colors: [colors[0].opacity(0.18), DashboardPalette.panel, colors[1].opacity(0.13)], startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(DashboardPalette.border))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
        .foregroundStyle(DashboardPalette.text)
    }
}

private struct DashboardPanel<Content: View>: View {
    let title: String
    let subtitle: String
    var minimumHeight: CGFloat? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 20, weight: .bold, design: .rounded))
                Text(subtitle).font(.caption).foregroundStyle(DashboardPalette.text.opacity(0.45)).lineLimit(2)
            }
            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
        .background(
            LinearGradient(colors: [DashboardPalette.panelTop, DashboardPalette.panel], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DashboardPalette.border))
        .shadow(color: .black.opacity(0.20), radius: 20, y: 12)
        .foregroundStyle(DashboardPalette.text)
    }
}

private struct IdentityRow: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                Image(systemName: icon).foregroundStyle(tint).frame(width: 22)
                Text(title).foregroundStyle(DashboardPalette.text.opacity(0.55))
                Spacer()
                Text(value).fontWeight(.medium).lineLimit(1).truncationMode(.middle)
            }
            .font(.system(size: 13))
            .frame(height: 48)
            if showsDivider { Divider().overlay(DashboardPalette.border) }
        }
    }
}

private enum DashboardPalette {
    static let canvas = adaptive(
        light: NSColor(calibratedRed: 0.84, green: 0.87, blue: 0.83, alpha: 0.78),
        dark: NSColor(calibratedRed: 0.015, green: 0.025, blue: 0.10, alpha: 1)
    )
    static let sidebar = adaptive(
        light: NSColor(calibratedRed: 0.88, green: 0.90, blue: 0.87, alpha: 0.76),
        dark: NSColor(calibratedRed: 0.105, green: 0.055, blue: 0.135, alpha: 1)
    )
    static let sidebarBottom = adaptive(
        light: NSColor(calibratedRed: 0.78, green: 0.83, blue: 0.78, alpha: 0.72),
        dark: NSColor(calibratedRed: 0.075, green: 0.055, blue: 0.16, alpha: 1)
    )
    static let panel = adaptive(
        light: NSColor(calibratedWhite: 0.96, alpha: 0.52),
        dark: NSColor(calibratedRed: 0.115, green: 0.075, blue: 0.18, alpha: 1)
    )
    static let panelTop = adaptive(
        light: NSColor(calibratedWhite: 1.0, alpha: 0.68),
        dark: NSColor(calibratedRed: 0.20, green: 0.11, blue: 0.22, alpha: 1)
    )
    static let text = adaptive(
        light: NSColor(calibratedWhite: 0.10, alpha: 1),
        dark: NSColor(calibratedWhite: 1, alpha: 1)
    )
    static let border = adaptive(
        light: NSColor(calibratedWhite: 1, alpha: 0.72),
        dark: NSColor(calibratedWhite: 1, alpha: 0.10)
    )
    static let glassFill = adaptive(
        light: NSColor(calibratedWhite: 0, alpha: 0.055),
        dark: NSColor(calibratedWhite: 1, alpha: 0.07)
    )
    static let coral = Color(red: 1.0, green: 0.36, blue: 0.29)
    static let pink = Color(red: 0.96, green: 0.28, blue: 0.62)
    static let purple = Color(red: 0.57, green: 0.30, blue: 0.90)
    static let blue = Color(red: 0.20, green: 0.47, blue: 1.0)

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}

private struct RulesSettingsView: View {
    @Binding var settings: GuardSettings
    let testStatuses: [UUID: RuleTestStatus]
    let onTest: (UUID) -> Void
    @State private var expandedRuleID: UUID?
    @State private var countryRuleID: UUID?
    @State private var applicationRuleID: UUID?

    var body: some View {
        ZStack {
            DashboardPalette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if settings.rules.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach($settings.rules) { $rule in
                                RuleStackCard(
                                    rule: $rule,
                                    isExpanded: expandedRuleID == rule.id,
                                    onToggleExpansion: {
                                        withAnimation(.snappy(duration: 0.24)) {
                                            expandedRuleID = expandedRuleID == rule.id ? nil : rule.id
                                        }
                                    },
                                    onChooseCountry: { countryRuleID = rule.id },
                                    onChooseApplication: { applicationRuleID = rule.id },
                                    testStatus: testStatuses[rule.id],
                                    onTest: { onTest(rule.id) },
                                    onDelete: { removeRule(rule.id) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 42)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: countrySheetPresented) {
            SingleCountryPicker(selection: selectedCountryValue)
        }
        .sheet(isPresented: applicationSheetPresented) {
            RuleApplicationPicker { application in
                guard let index = selectedApplicationRuleIndex else { return }
                settings.rules[index].application = GuardRule.Application(
                    bundleIdentifier: application.bundleIdentifier,
                    displayName: application.displayName,
                    url: application.url
                )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text("保护规则")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
            }
            Spacer()
            Button(action: toggleAllRules) {
                Label(allRulesEnabled ? "全部关闭" : "全部开启", systemImage: allRulesEnabled ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(DashboardPalette.glassFill, in: Capsule())
                    .overlay(Capsule().stroke(DashboardPalette.border))
            }
            .buttonStyle(.plain)
            .disabled(settings.rules.isEmpty)
            Label(
                settings.isProtectionActive ? "保护已启用" : "保护未启用",
                systemImage: settings.isProtectionActive ? "shield.checkered" : "shield.slash"
            )
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(settings.isProtectionActive ? Color.green : DashboardPalette.coral)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(DashboardPalette.glassFill, in: Capsule())
            Button(action: addRule) {
                Label("新增规则", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(
                        LinearGradient(colors: [DashboardPalette.coral, DashboardPalette.pink, DashboardPalette.blue], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var allRulesEnabled: Bool {
        !settings.rules.isEmpty && settings.rules.allSatisfy { $0.isEnabled }
    }

    private func toggleAllRules() {
        withAnimation(.snappy(duration: 0.24)) {
            settings.setProtectionActive(!allRulesEnabled)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(DashboardPalette.purple.opacity(0.16))
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(DashboardPalette.purple)
            }
            .frame(width: 64, height: 64)
            Text("还没有保护规则").font(.title3.bold())
            Text("创建一条规则，定义出口条件以及要打开或关闭的应用。")
                .foregroundStyle(DashboardPalette.text.opacity(0.46))
            Button("创建第一条规则", action: addRule)
                .buttonStyle(.borderedProminent)
                .tint(DashboardPalette.purple)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DashboardPalette.border))
        .foregroundStyle(DashboardPalette.text)
    }

    private func addRule() {
        let rule = GuardRule()
        withAnimation(.snappy(duration: 0.24)) {
            settings.addRule(rule)
            expandedRuleID = rule.id
        }
    }

    private func removeRule(_ id: UUID) {
        withAnimation(.snappy(duration: 0.24)) {
            settings.rules.removeAll { $0.id == id }
            if expandedRuleID == id { expandedRuleID = nil }
        }
    }

    private var countrySheetPresented: Binding<Bool> {
        Binding(get: { countryRuleID != nil }, set: { if !$0 { countryRuleID = nil } })
    }

    private var selectedCountryValue: Binding<String> {
        Binding(
            get: { countryRuleID.flatMap { id in settings.rules.first(where: { $0.id == id })?.value } ?? "" },
            set: { value in
                guard let id = countryRuleID, let index = settings.rules.firstIndex(where: { $0.id == id }) else { return }
                settings.rules[index].value = value
            }
        )
    }

    private var applicationSheetPresented: Binding<Bool> {
        Binding(get: { applicationRuleID != nil }, set: { if !$0 { applicationRuleID = nil } })
    }

    private var selectedApplicationRuleIndex: Int? {
        guard let id = applicationRuleID else { return nil }
        return settings.rules.firstIndex { $0.id == id }
    }
}

private struct RuleStackCard: View {
    @Binding var rule: GuardRule
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onChooseCountry: () -> Void
    let onChooseApplication: () -> Void
    let testStatus: RuleTestStatus?
    let onTest: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            summary
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggleExpansion)
            if isExpanded {
                Divider().overlay(DashboardPalette.border)
                editor
                    .transition(.opacity)
            }
        }
        .background(
            LinearGradient(colors: [DashboardPalette.panelTop, DashboardPalette.panel], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(isExpanded ? DashboardPalette.purple.opacity(0.55) : DashboardPalette.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        .foregroundStyle(DashboardPalette.text)
    }

    private var summary: some View {
        HStack(spacing: 12) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DashboardPalette.text.opacity(0.38))
                .frame(width: 16)

            Text(rule.perspective.title)
                .foregroundStyle(DashboardPalette.purple)
                .fontWeight(.semibold)
            Text(rule.comparison.title)
                .foregroundStyle(rule.comparison == .isEqual ? DashboardPalette.coral : DashboardPalette.pink)
                .fontWeight(.semibold)
            Text(rule.condition.title).foregroundStyle(DashboardPalette.text.opacity(0.58))
            conditionValue
            Image(systemName: "arrow.right")
                .font(.caption).foregroundStyle(DashboardPalette.text.opacity(0.28))
            Text(rule.action.title)
                .foregroundStyle(rule.action == .close ? DashboardPalette.coral : .green)
                .fontWeight(.semibold)
            applicationSummary
            Spacer(minLength: 8)
            Toggle("", isOn: $rule.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .onTapGesture { }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 18)
        .frame(minHeight: 66)
        .opacity(rule.isEnabled ? 1 : 0.52)
    }

    @ViewBuilder private var conditionValue: some View {
        if rule.value.isEmpty {
            Text("尚未设置").foregroundStyle(DashboardPalette.text.opacity(0.30)).italic()
        } else if rule.condition == .country {
            Text("\(CountryOption.flag(for: rule.value)) \(Locale.current.localizedString(forRegionCode: rule.value) ?? rule.value)")
                .fontWeight(.semibold)
        } else {
            Text(rule.value).font(.system(.body, design: .monospaced)).fontWeight(.semibold)
        }
    }

    @ViewBuilder private var applicationSummary: some View {
        if let application = rule.application {
            RuleApplicationIcon(url: application.url).frame(width: 26, height: 26)
            Text(application.displayName).fontWeight(.medium).lineLimit(1)
        } else {
            Image(systemName: "app.dashed").foregroundStyle(DashboardPalette.text.opacity(0.30))
            Text("选择应用").foregroundStyle(DashboardPalette.text.opacity(0.30))
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                RuleMenu(title: "出口", selection: $rule.perspective)
                RuleMenu(title: "关系", selection: $rule.comparison)
                RuleMenu(title: "条件", selection: $rule.condition)
                conditionEditor
                RuleMenu(title: "动作", selection: $rule.action)
            }

            HStack {
                Button(action: onChooseApplication) {
                    HStack(spacing: 10) {
                        if let application = rule.application {
                            RuleApplicationIcon(url: application.url).frame(width: 30, height: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(application.displayName).fontWeight(.semibold)
                                Text(application.bundleIdentifier).font(.caption2).foregroundStyle(DashboardPalette.text.opacity(0.38))
                            }
                        } else {
                            Image(systemName: "plus.app.fill").foregroundStyle(DashboardPalette.purple)
                            Text("选择目标应用").fontWeight(.semibold)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(DashboardPalette.text.opacity(0.35))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 50)
                    .background(DashboardPalette.glassFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onTest) {
                    Label(testButtonTitle, systemImage: testButtonSymbol)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .buttonStyle(.bordered)
                .tint(testButtonTint)
                .disabled(rule.application == nil || testStatus == .running)
                .help("直接测试该规则配置的应用动作，不判断当前出口条件")

                Button(role: .destructive, action: onDelete) {
                    Label("删除规则", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(DashboardPalette.coral)
            }

            if !isValueValid {
                Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.caption).foregroundStyle(DashboardPalette.coral)
            }
            if let testStatus, let detail = testStatus.detail {
                Label(detail, systemImage: testButtonSymbol)
                    .font(.caption)
                    .foregroundStyle(testButtonTint)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
    }

    private var testButtonTitle: String {
        switch testStatus {
        case .running: "TESTING"
        case .succeeded: "SUCCESS"
        case .failed: "FAILED"
        case .unavailable: "NO APP"
        case nil: "TEST"
        }
    }

    private var testButtonSymbol: String {
        switch testStatus {
        case .running: "hourglass"
        case .succeeded: "checkmark.circle.fill"
        case .failed, .unavailable: "xmark.circle.fill"
        case nil: "play.fill"
        }
    }

    private var testButtonTint: Color {
        switch testStatus {
        case .succeeded: .green
        case .failed, .unavailable: DashboardPalette.coral
        default: DashboardPalette.purple
        }
    }

    @ViewBuilder private var conditionEditor: some View {
        if rule.condition == .country {
            Button(action: onChooseCountry) {
                HStack {
                    Text(rule.value.isEmpty ? "选择国家或地区" : "\(CountryOption.flag(for: rule.value)) \(Locale.current.localizedString(forRegionCode: rule.value) ?? rule.value)")
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption)
                }
                .padding(.horizontal, 11)
                .frame(minWidth: 190, minHeight: 38)
                .background(DashboardPalette.glassFill, in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
        } else {
            TextField(rule.condition == .ip ? "例如 203.0.113.10" : "例如 203.0.113.0/24", text: $rule.value)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 11)
                .frame(minWidth: 190, minHeight: 38)
                .background(DashboardPalette.glassFill, in: RoundedRectangle(cornerRadius: 9))
        }
    }

    private var isValueValid: Bool {
        if rule.value.isEmpty { return true }
        switch rule.condition {
        case .ip: return IPNetwork.isValidAddress(rule.value)
        case .cidr: return (try? IPNetwork(rule.value)) != nil
        case .country: return rule.value.count == 2
        }
    }

    private var validationMessage: String {
        rule.condition == .ip ? "请输入有效的 IPv4 地址" : "请输入有效的 CIDR 网段"
    }
}

private struct RuleMenu<Value: Hashable & Identifiable & CaseIterable>: View where Value.AllCases: RandomAccessCollection, Value.AllCases.Element == Value {
    let title: String
    @Binding var selection: Value

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(Value.allCases) { value in
                Text(menuTitle(value)).tag(value)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
    }

    private func menuTitle(_ value: Value) -> String {
        if let value = value as? GuardRule.Perspective { return value.title }
        if let value = value as? GuardRule.Comparison { return value.title }
        if let value = value as? GuardRule.Condition { return value.title }
        if let value = value as? GuardRule.Action { return value.title }
        return String(describing: value)
    }
}

private struct CountryOption: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }

    static let all: [CountryOption] = Locale.Region.isoRegions.compactMap { region in
        let code = region.identifier
        guard let name = Locale.current.localizedString(forRegionCode: code) else { return nil }
        return CountryOption(code: code, name: name)
    }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    static func flag(for code: String) -> String {
        RegionFlag.symbol(for: code)
    }
}

enum RegionFlag {
    static func symbol(for code: String) -> String {
        let scalars = Array(code.uppercased().unicodeScalars)
        guard scalars.count == 2,
              scalars.allSatisfy({ (65...90).contains($0.value) }) else {
            return "--"
        }
        return String(String.UnicodeScalarView(scalars.compactMap { UnicodeScalar(127_397 + $0.value) }))
    }
}

private struct SingleCountryPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String
    @State private var searchText = ""

    private var countries: [CountryOption] {
        guard !searchText.isEmpty else { return CountryOption.all }
        return CountryOption.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) || $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择国家或地区").font(.title2.bold())
                Spacer()
                Button("取消") { dismiss() }
            }
            .padding()
            List(countries) { country in
                Button {
                    selection = country.code
                    dismiss()
                } label: {
                    HStack {
                        Text(CountryOption.flag(for: country.code))
                        Text(country.name)
                        Spacer()
                        Text(country.code).foregroundStyle(.secondary)
                        if selection == country.code { Image(systemName: "checkmark.circle.fill").foregroundStyle(DashboardPalette.purple) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "搜索国家、地区或代码")
        }
        .frame(width: 520, height: 560)
    }
}

private struct RuleApplicationPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var applications: [InstalledApplication] = []
    @State private var searchText = ""
    let onSelect: (InstalledApplication) -> Void

    private var filtered: [InstalledApplication] {
        guard !searchText.isEmpty else { return applications }
        return applications.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择目标应用").font(.title2.bold())
                Spacer()
                Button("取消") { dismiss() }
            }
            .padding()
            List(filtered) { application in
                Button {
                    onSelect(application)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        RuleApplicationIcon(url: application.url).frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(application.displayName)
                            Text(application.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if application.isRunning {
                            Text("运行中")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 7)
                                .frame(height: 20)
                                .background(.green.opacity(0.12), in: Capsule())
                                .overlay(Capsule().stroke(.green.opacity(0.22)))
                        }
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "搜索已安装应用")
        }
        .frame(width: 560, height: 500)
        .task { applications = await ApplicationCatalog().applications() }
    }
}

private struct RuleApplicationIcon: View {
    let url: URL?

    var body: some View {
        Group {
            if let url { Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable() }
            else { Image(systemName: "app.fill").resizable() }
        }
        .scaledToFit()
    }
}

private struct PreferencesSettingsView: View {
    @Binding var settings: GuardSettings
    let identity: ExitIdentity?
    let status: GuardDisplayStatus

    var body: some View {
        ZStack {
            DashboardPalette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("设置")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("配置自动检测频率和 macOS 顶部状态栏的展示内容。")
                            .font(.system(size: 14))
                            .foregroundStyle(DashboardPalette.text.opacity(0.52))
                    }

                    DashboardPanel(title: "自动检测", subtitle: "网络状态变化时仍会立即检测，此处作为周期兜底") {
                        HStack(spacing: 14) {
                            Image(systemName: "timer")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(DashboardPalette.coral)
                                .frame(width: 38, height: 38)
                                .background(DashboardPalette.coral.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("自动刷新间隔").font(.system(size: 14, weight: .semibold))
                                Text("最短 1 秒，修改后立即应用").font(.caption).foregroundStyle(DashboardPalette.text.opacity(0.42))
                            }
                            Spacer()
                            TextField("30", value: intervalValue, format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.plain)
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .multilineTextAlignment(.trailing)
                                .padding(.horizontal, 12)
                                .frame(width: 108, height: 38)
                                .background(DashboardPalette.glassFill, in: RoundedRectangle(cornerRadius: 9))
                            Picker("单位", selection: intervalUnit) {
                                ForEach(RefreshIntervalUnit.allCases) { unit in
                                    Text(unit.title).tag(unit)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 92)
                        }
                    }

                    DashboardPanel(title: "顶部状态栏展示", subtitle: "控制菜单栏图标右侧显示的出口身份信息") {
                        VStack(spacing: 0) {
                            preferenceRow(
                                icon: "shield.slash",
                                title: "显示盾牌状态图标",
                                subtitle: "关闭后使用出口身份文字作为菜单栏入口"
                            ) {
                                Toggle("", isOn: $settings.showsStatusIconInMenuBar).labelsHidden().toggleStyle(.switch)
                            }

                            Divider().overlay(DashboardPalette.border)

                            preferenceRow(
                                icon: "network",
                                title: "显示当前出网 IP",
                                subtitle: "在菜单栏中展示当前检测到的出口地址"
                            ) {
                                Toggle("", isOn: showsIPBinding).labelsHidden().toggleStyle(.switch)
                            }

                            Divider().overlay(DashboardPalette.border)

                            preferenceRow(
                                icon: "textformat.abc",
                                title: "IP 展示方式",
                                subtitle: "完整地址或前两段缩写"
                            ) {
                                Picker("IP 展示方式", selection: ipDisplayBinding) {
                                    Text("完整 IPv4").tag(MenuBarIPDisplayMode.fullIPv4)
                                    Text("前两段缩写").tag(MenuBarIPDisplayMode.abbreviatedIPv4)
                                }
                                .labelsHidden()
                                .disabled(!settings.showsIPInMenuBar)
                            }

                            Divider().overlay(DashboardPalette.border)

                            preferenceRow(
                                icon: "flag.fill",
                                title: "国家或地区",
                                subtitle: "可隐藏，或使用国旗、两字母代码展示"
                            ) {
                                Picker("国家或地区", selection: $settings.menuBarCountryDisplayMode) {
                                    ForEach(MenuBarCountryDisplayMode.allCases) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                    }

                    DashboardPanel(title: "展示预览", subtitle: "顶部状态栏将按照以下组合显示") {
                        HStack(spacing: 10) {
                            if settings.showsStatusIconInMenuBar || menuBarPreview == nil {
                                Image(systemName: status.menuBarSymbolName)
                                    .symbolRenderingMode(.monochrome)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(status.color)
                                    .frame(width: 20, height: 20)
                            }
                            if let preview = menuBarPreview {
                                Text(preview)
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            } else {
                                Text("仅显示状态图标").foregroundStyle(DashboardPalette.text.opacity(0.48))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(DashboardPalette.glassFill, in: RoundedRectangle(cornerRadius: 11))
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 42)
                .padding(.bottom, 34)
            }
        }
    }

    private var intervalValue: Binding<Double> {
        Binding(
            get: { settings.checkIntervalValue },
            set: { settings.setCheckInterval(value: $0, unit: settings.checkIntervalUnit) }
        )
    }

    private var intervalUnit: Binding<RefreshIntervalUnit> {
        Binding(
            get: { settings.checkIntervalUnit },
            set: { settings.setCheckIntervalUnit($0) }
        )
    }

    private var showsIPBinding: Binding<Bool> {
        Binding(get: { settings.showsIPInMenuBar }, set: { settings.showsIPInMenuBar = $0 })
    }

    private var ipDisplayBinding: Binding<MenuBarIPDisplayMode> {
        Binding(
            get: { settings.menuBarIPDisplayMode == .abbreviatedIPv4 ? .abbreviatedIPv4 : .fullIPv4 },
            set: { settings.menuBarIPDisplayMode = $0 }
        )
    }

    private var menuBarPreview: String? {
        let previewIP = identity?.ipv4Address ?? "203.0.113.10"
        let previewCountry = identity?.countryCode?.uppercased() ?? "SG"
        var parts: [String] = []
        switch settings.menuBarCountryDisplayMode {
        case .hidden: break
        case .flag: parts.append(identity?.countryFlag ?? "🇸🇬")
        case .code: parts.append(previewCountry)
        }
        switch settings.menuBarIPDisplayMode {
        case .iconOnly: break
        case .fullIPv4: parts.append(previewIP)
        case .abbreviatedIPv4: parts.append(previewIP.abbreviatedIPv4)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func preferenceRow<Accessory: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .foregroundStyle(DashboardPalette.purple)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(subtitle).font(.caption).foregroundStyle(DashboardPalette.text.opacity(0.42))
            }
            Spacer()
            accessory()
        }
        .frame(minHeight: 58)
    }
}

private struct EmailSettingsView: View {
    @Bindable var model: AppModel
    @State private var showsPassword = false

    var body: some View {
        ZStack {
            DashboardPalette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    DashboardPanel(title: "SMTP 邮件配置", subtitle: "密码或授权码保存在 macOS 钥匙串中") {
                        VStack(spacing: 0) {
                            emailRow(icon: "power", title: "推送邮件通知", subtitle: "IP 变更、规则执行或运行失败时发送") {
                                Toggle("", isOn: $model.settings.email.isEnabled)
                                    .labelsHidden().toggleStyle(.switch)
                                    .disabled(
                                        !model.settings.email.isEnabled &&
                                            (!model.settings.email.isComplete || model.emailPassword.isEmpty)
                                    )
                            }
                            Divider().overlay(DashboardPalette.border)
                            fields
                        }
                    }

                    DashboardPanel(title: "测试配置", subtitle: "保存会自动完成；测试将使用上方当前配置") {
                        HStack(spacing: 14) {
                            Button(action: model.testEmail) {
                                Label(testButtonTitle, systemImage: testButtonSymbol)
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 15).frame(height: 40)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(DashboardPalette.purple)
                            .disabled(model.emailTestStatus == .sending || !model.settings.email.isComplete || model.emailPassword.isEmpty)
                            if let message = model.emailTestStatus.message {
                                Label(message, systemImage: testButtonSymbol)
                                    .font(.caption)
                                    .foregroundStyle(testTint)
                                    .textSelection(.enabled)
                            } else {
                                Text("请先填写完整配置，再发送测试邮件")
                                    .font(.caption).foregroundStyle(DashboardPalette.text.opacity(0.42))
                            }
                        }
                    }
                }
                .padding(.horizontal, 34).padding(.top, 42).padding(.bottom, 34)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("邮件通知").font(.system(size: 30, weight: .bold, design: .rounded))
            Text("配置告警收件邮箱和 SMTP 发件服务。")
                .font(.system(size: 14)).foregroundStyle(DashboardPalette.text.opacity(0.52))
        }
    }

    private var fields: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                mailField("SMTP 服务器", text: $model.settings.email.smtpHost, prompt: "smtp.example.com")
                VStack(alignment: .leading, spacing: 6) {
                    Text("端口").font(.caption).foregroundStyle(DashboardPalette.text.opacity(0.48))
                    TextField("465", value: $model.settings.email.smtpPort, format: .number)
                        .textFieldStyle(.plain).padding(.horizontal, 11).frame(width: 90, height: 38)
                        .background(DashboardPalette.glassFill, in: RoundedRectangle(cornerRadius: 9))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("连接安全").font(.caption).foregroundStyle(DashboardPalette.text.opacity(0.48))
                    Picker("连接安全", selection: $model.settings.email.security) {
                        ForEach(EmailConfiguration.Security.allCases) { security in Text(security.title).tag(security) }
                    }.labelsHidden().frame(width: 120)
                }
            }
            HStack(spacing: 14) {
                mailField("SMTP 用户名", text: $model.settings.email.username, prompt: "name@example.com")
                VStack(alignment: .leading, spacing: 6) {
                    Text("密码 / 授权码").font(.caption).foregroundStyle(DashboardPalette.text.opacity(0.48))
                    HStack(spacing: 8) {
                        Group {
                            if showsPassword {
                                TextField("SMTP 密码或授权码", text: $model.emailPassword)
                            } else {
                                SecureField("SMTP 密码或授权码", text: $model.emailPassword)
                            }
                        }
                        .textFieldStyle(.plain)

                        Button {
                            showsPassword.toggle()
                        } label: {
                            Image(systemName: showsPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundStyle(DashboardPalette.text.opacity(0.48))
                                .frame(width: 22, height: 28)
                        }
                        .buttonStyle(.plain)
                        .help(showsPassword ? "隐藏密码或授权码" : "显示密码或授权码")
                        .accessibilityLabel(showsPassword ? "隐藏密码或授权码" : "显示密码或授权码")
                    }
                    .padding(.leading, 11)
                    .padding(.trailing, 7)
                    .frame(height: 38)
                    .background(DashboardPalette.glassFill, in: RoundedRectangle(cornerRadius: 9))
                }.frame(maxWidth: .infinity)
            }
            HStack(spacing: 14) {
                mailField("发件邮箱", text: $model.settings.email.senderAddress, prompt: "sender@example.com")
                mailField("收件邮箱", text: $model.settings.email.recipientAddress, prompt: "alerts@example.com")
            }
        }.padding(.top, 16)
    }

    private func mailField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(DashboardPalette.text.opacity(0.48))
            TextField(prompt, text: text)
                .textFieldStyle(.plain).padding(.horizontal, 11).frame(height: 38)
                .background(DashboardPalette.glassFill, in: RoundedRectangle(cornerRadius: 9))
        }.frame(maxWidth: .infinity)
    }

    private func emailRow<Accessory: View>(icon: String, title: String, subtitle: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon).foregroundStyle(DashboardPalette.purple).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(subtitle).font(.caption).foregroundStyle(DashboardPalette.text.opacity(0.42))
            }
            Spacer(); accessory()
        }.frame(minHeight: 58)
    }

    private var testButtonTitle: String {
        switch model.emailTestStatus {
        case .sending: "发送中"
        case .succeeded: "再次测试"
        default: "发送测试邮件"
        }
    }

    private var testButtonSymbol: String {
        switch model.emailTestStatus {
        case .sending: "hourglass"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .idle: "paperplane.fill"
        }
    }

    private var testTint: Color {
        if case .failed = model.emailTestStatus { return DashboardPalette.coral }
        if case .succeeded = model.emailTestStatus { return .green }
        return DashboardPalette.purple
    }
}

private struct LocalNetworkMonitorView: View {
    @State private var snapshot = LocalNetworkSnapshot.empty
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var routeFilter: LocalRouteFilter = .policy
    private let monitor = SystemLocalNetworkMonitor()

    private var displayedRoutes: [LocalRouteEntry] {
        switch routeFilter {
        case .policy: snapshot.routes.filter(\.isPolicyRoute)
        case .direct: snapshot.routes.filter { $0.kind == .directNetwork || $0.kind == .other }
        case .neighbors: snapshot.routes.filter { $0.kind == .neighborCache }
        case .all: snapshot.routes
        }
    }

    var body: some View {
        ZStack {
            DashboardPalette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    summary
                    interfacePanel
                    routePanel
                }
                .padding(.horizontal, 34)
                .padding(.top, 42)
                .padding(.bottom, 34)
            }
        }
        .task { await startMonitoringAfterNavigation() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text("本地网络")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("只读监看本地网卡和 IPv4 路由表，不修改系统网络配置。")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardPalette.text.opacity(0.52))
            }
            Spacer()
            Button { Task { await refresh() } } label: {
                Label(isRefreshing ? "读取中" : "立即刷新", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(DashboardPalette.glassFill, in: Capsule())
                    .overlay(Capsule().stroke(DashboardPalette.border))
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            networkMetric("活动网卡", value: snapshot.interfaces.filter(\.isActive).count, icon: "network", tint: DashboardPalette.blue)
            networkMetric("策略路由", value: snapshot.routes.filter(\.isPolicyRoute).count, icon: "point.3.connected.trianglepath.dotted", tint: DashboardPalette.coral)
            networkMetric("全部路由", value: snapshot.routes.count, icon: "arrow.triangle.branch", tint: DashboardPalette.purple)
        }
    }

    private func networkMetric(_ title: String, value: Int, icon: String, tint: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)").font(.system(size: 19, weight: .bold, design: .rounded))
                Text(title).font(.caption).foregroundStyle(DashboardPalette.text.opacity(0.48))
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(DashboardPalette.glassFill, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(DashboardPalette.border))
    }

    private var interfacePanel: some View {
        DashboardPanel(title: "本地网卡", subtitle: "类型结合系统硬件端口元数据和 BSD 接口名称判断；来源无法确定时会明确标注") {
            if snapshot.interfaces.isEmpty {
                emptyState("尚未读取到网卡", icon: "network.slash")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(snapshot.interfaces) { interface in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: interface.kind.symbolName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(interface.isActive ? DashboardPalette.blue : Color.secondary)
                                .frame(width: 24, height: 24)
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Text(interface.name).font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    Text(interface.kind.title)
                                        .font(.caption2).foregroundStyle(DashboardPalette.blue)
                                        .padding(.horizontal, 6).frame(height: 18)
                                        .background(DashboardPalette.blue.opacity(0.10), in: Capsule())
                                    Text(interface.isActive ? "活动" : "未活动")
                                        .font(.caption2).foregroundStyle(interface.isActive ? .green : .secondary)
                                }
                                if let displayName = interface.displayName, displayName != interface.name {
                                    Text(displayName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(DashboardPalette.text.opacity(0.68))
                                }
                                Text(interface.addresses.isEmpty ? "无 IP 地址" : interface.addresses.joined(separator: "  ·  "))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(DashboardPalette.text.opacity(0.58))
                                    .textSelection(.enabled)
                                HStack(spacing: 8) {
                                    Text(interface.kind.sourceDescription)
                                    if let hardwareAddress = interface.hardwareAddress {
                                        Text("·")
                                        Text(hardwareAddress).fontDesign(.monospaced)
                                    }
                                }
                                .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 9)
                        Divider().overlay(DashboardPalette.border)
                    }
                }
            }
        }
    }

    private var routePanel: some View {
        DashboardPanel(title: "流量路由", subtitle: "单个 IP 条目通常是动态邻居缓存，并非把 CIDR 展开；默认只展示影响流量走向的策略路由") {
            VStack(spacing: 12) {
                HStack {
                    Picker("路由范围", selection: $routeFilter) {
                        ForEach(LocalRouteFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 350)
                    Spacer()
                    if snapshot.checkedAt != .distantPast {
                        Text("更新于 \(snapshot.checkedAt.formatted(date: .omitted, time: .standard))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(DashboardPalette.coral)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if displayedRoutes.isEmpty {
                    emptyState(routeFilter.emptyMessage, icon: "arrow.triangle.branch")
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedRoutes) { route in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 7) {
                                        Text(route.destination)
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                        Text(route.kind.title)
                                            .font(.caption2)
                                            .foregroundStyle(route.kind == .neighborCache ? Color.secondary : DashboardPalette.coral)
                                    }
                                    Text("flags \(route.flags)")
                                        .font(.caption2.monospaced()).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                                Text(route.gateway)
                                    .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                                Text(route.interfaceName)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(DashboardPalette.blue)
                                    .frame(width: 52, alignment: .trailing)
                            }
                            .padding(.vertical, 10)
                            Divider().overlay(DashboardPalette.border)
                        }
                    }
                }
            }
        }
    }

    private func emptyState(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 74)
    }

    private func monitorContinuously() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(5))
        }
    }

    private func startMonitoringAfterNavigation() async {
        do {
            try await Task.sleep(for: .seconds(SettingsLayoutMetrics.localNetworkInitialLoadDelay))
        } catch {
            return
        }
        await monitorContinuously()
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let refreshedSnapshot = try await monitor.snapshot()
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                snapshot = refreshedSnapshot
                errorMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum LocalRouteFilter: String, CaseIterable, Identifiable {
    case policy
    case direct
    case neighbors
    case all

    var id: Self { self }

    var title: String {
        switch self {
        case .policy: "策略"
        case .direct: "直连"
        case .neighbors: "邻居"
        case .all: "全部"
        }
    }

    var emptyMessage: String {
        switch self {
        case .policy: "没有检测到默认、静态或 TUN 策略路由"
        case .direct: "没有检测到直连网段"
        case .neighbors: "当前没有动态邻居缓存"
        case .all: "没有读取到 IPv4 路由"
        }
    }
}

private struct RuntimeLogView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            DashboardPalette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if model.runtimeLogs.isEmpty {
                        ContentUnavailableView("暂无运行日志", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity, minHeight: 360)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(model.runtimeLogs.reversed()) { entry in
                                RuntimeLogRow(entry: entry)
                            }
                        }
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 42)
                .padding(.bottom, 34)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text("运行日志")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("记录本次启动中的初始化、检测、规则运行与错误，便于定位耗时和故障。")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardPalette.text.opacity(0.52))
            }
            Spacer()
            Label("最近 \(model.runtimeLogs.count) 条", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DashboardPalette.text.opacity(0.64))
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(DashboardPalette.glassFill, in: Capsule())
                .overlay(Capsule().stroke(DashboardPalette.border))
        }
    }
}

private struct RuntimeLogRow: View {
    let entry: RuntimeLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(levelColor.opacity(0.14))
                Image(systemName: entry.category.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(levelColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(entry.message).font(.system(size: 14, weight: .semibold))
                    Text(entry.category.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(levelColor)
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(levelColor.opacity(0.10), in: Capsule())
                }
                if let detail = entry.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardPalette.text.opacity(0.52))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 12)
            Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DashboardPalette.text.opacity(0.42))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [DashboardPalette.panelTop, DashboardPalette.panel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(DashboardPalette.border))
    }

    private var levelColor: Color {
        switch entry.level {
        case .info: DashboardPalette.blue
        case .success: .green
        case .warning: .orange
        case .error: DashboardPalette.coral
        }
    }
}

private struct PlaceholderSettingsView: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: "hammer", description: Text(message))
            .navigationTitle(title)
    }
}
