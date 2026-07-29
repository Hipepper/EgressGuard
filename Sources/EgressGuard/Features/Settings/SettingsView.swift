import SwiftUI
import AppKit

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $model.selectedSettingsSection)
                .frame(width: 228)
            Group {
                switch model.selectedSettingsSection ?? .overview {
                case .overview: OverviewDashboardView(model: model)
                case .rules: RulesSettingsView(settings: $model.settings)
                case .applications: ApplicationPickerView(model: model)
                case .notifications: PlaceholderSettingsView(title: "通知", message: "飞书 Webhook 与邮件通知将在通知阶段接入。")
                case .history: PlaceholderSettingsView(title: "历史记录", message: "检测与处置历史将在持久化阶段接入。")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DashboardPalette.canvas)
        }
        .background(DashboardPalette.sidebar)
        .preferredColorScheme(.dark)
    }
}

private struct SettingsSidebar: View {
    @Binding var selection: SettingsSection?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text("EgressGuard").font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("出口安全控制台").font(.caption2).foregroundStyle(.white.opacity(0.48))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)

            VStack(spacing: 5) {
                ForEach(SettingsSection.allCases) { section in
                    Button { selection = section } label: {
                        HStack(spacing: 11) {
                            Image(systemName: section.symbolName)
                                .font(.system(size: 14, weight: .medium)).frame(width: 20)
                            Text(section.title).fontWeight(selection == section ? .semibold : .regular)
                            Spacer()
                        }
                        .foregroundStyle(selection == section ? Color.white : Color.white.opacity(0.62))
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
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)

            Spacer()
            HStack(spacing: 8) {
                Circle().fill(.green).frame(width: 7, height: 7)
                    .shadow(color: .green.opacity(0.8), radius: 5)
                Text("本地保护服务运行中").font(.caption).foregroundStyle(.white.opacity(0.48))
            }
            .padding(20)
        }
        .padding(.top, 52)
        .background(
            LinearGradient(colors: [DashboardPalette.sidebar, DashboardPalette.sidebarBottom], startPoint: .top, endPoint: .bottom)
        )
    }
}

private struct OverviewDashboardView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack(alignment: .top) {
            DashboardPalette.canvas
            LinearGradient(
                colors: [DashboardPalette.coral, DashboardPalette.pink, DashboardPalette.blue],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 210)
            .overlay(alignment: .trailing) {
                Image(systemName: "network")
                    .font(.system(size: 170, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.08))
                    .padding(.trailing, 34)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    dashboardHeader
                    metricCards
                    HStack(alignment: .top, spacing: 20) {
                        identityPanel
                        policyPanel.frame(width: 300)
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
        .frame(height: 98, alignment: .top)
    }

    private var metricCards: some View {
        HStack(spacing: 18) {
            MetricCard(icon: model.status.symbolName, value: model.status.title,
                       label: model.settings.isProtectionEnabled ? "出口保护已启用" : "出口保护未启用",
                       colors: [DashboardPalette.coral, DashboardPalette.pink])
            MetricCard(icon: "globe.asia.australia.fill", value: model.identity?.ipv4Address ?? "等待检测",
                       label: model.identity.map { "\($0.countryFlag) \($0.countryName ?? "未知地区")" } ?? "当前公网 IPv4",
                       colors: [DashboardPalette.pink, DashboardPalette.purple])
            MetricCard(icon: "app.badge.checkmark.fill", value: "\(model.protectedApplications.count)",
                       label: "受保护应用", colors: [DashboardPalette.purple, DashboardPalette.blue])
        }
    }

    private var identityPanel: some View {
        DashboardPanel(title: "当前出口身份", subtitle: identitySubtitle) {
            VStack(spacing: 0) {
                IdentityRow(icon: "network", title: "IPv4 地址", value: model.identity?.ipv4Address ?? "—", tint: DashboardPalette.coral)
                IdentityRow(icon: "point.3.connected.trianglepath.dotted", title: "IPv6 地址", value: model.ipv6Address ?? "未检测到", tint: DashboardPalette.pink)
                IdentityRow(icon: "building.2", title: "网络归属", value: networkOwner, tint: DashboardPalette.purple)
                IdentityRow(icon: "mappin.and.ellipse", title: "国家或地区", value: countryDescription, tint: DashboardPalette.blue, showsDivider: false)
            }
        }
    }

    private var policyPanel: some View {
        DashboardPanel(title: "保护策略", subtitle: policySummary) {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $model.settings.isProtectionEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("启用出口保护").font(.system(size: 14, weight: .semibold))
                        Text(model.settings.hasPolicyConstraints ? "异常时按规则处置" : "请先添加保护规则")
                            .font(.caption).foregroundStyle(.white.opacity(0.46))
                    }
                }
                .toggleStyle(.switch)
                .disabled(!model.settings.hasPolicyConstraints)

                Divider().overlay(.white.opacity(0.08))
                Label("每 \(Int(model.settings.checkInterval)) 秒自动检测", systemImage: "timer")
                Label("连续 \(model.settings.violationThreshold) 次异常后触发", systemImage: "shield.lefthalf.filled")
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
            .foregroundStyle(.white.opacity(0.78))
        }
    }

    private var identitySubtitle: String {
        guard let identity = model.identity else { return "尚未获得检测结果" }
        return "由 \(identity.provider) 于 \(identity.checkedAt.formatted(date: .omitted, time: .shortened)) 更新"
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
                Circle().stroke(.white.opacity(0.16))
                Image(systemName: icon).font(.system(size: 22, weight: .medium))
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.system(size: 20, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                Text(label).font(.caption).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 92)
        .background(
            LinearGradient(colors: [colors[0].opacity(0.18), DashboardPalette.panel, colors[1].opacity(0.13)], startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.08)))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
    }
}

private struct DashboardPanel<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 20, weight: .bold, design: .rounded))
                Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.45)).lineLimit(2)
            }
            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [DashboardPalette.panelTop, DashboardPalette.panel], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08)))
        .shadow(color: .black.opacity(0.20), radius: 20, y: 12)
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
                Text(title).foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text(value).fontWeight(.medium).lineLimit(1).truncationMode(.middle)
            }
            .font(.system(size: 13))
            .frame(height: 48)
            if showsDivider { Divider().overlay(.white.opacity(0.07)) }
        }
    }
}

private enum DashboardPalette {
    static let canvas = Color(red: 0.015, green: 0.025, blue: 0.10)
    static let sidebar = Color(red: 0.105, green: 0.055, blue: 0.135)
    static let sidebarBottom = Color(red: 0.075, green: 0.055, blue: 0.16)
    static let panel = Color(red: 0.115, green: 0.075, blue: 0.18)
    static let panelTop = Color(red: 0.20, green: 0.11, blue: 0.22)
    static let coral = Color(red: 1.0, green: 0.36, blue: 0.29)
    static let pink = Color(red: 0.96, green: 0.28, blue: 0.62)
    static let purple = Color(red: 0.57, green: 0.30, blue: 0.90)
    static let blue = Color(red: 0.20, green: 0.47, blue: 1.0)
}

private struct RulesSettingsView: View {
    @Binding var settings: GuardSettings
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
                Text("从上到下管理出口条件；满足条件时执行指定的应用动作。")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.52))
            }
            Spacer()
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
                .foregroundStyle(.white.opacity(0.46))
            Button("创建第一条规则", action: addRule)
                .buttonStyle(.borderedProminent)
                .tint(DashboardPalette.purple)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.07)))
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
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            summary
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggleExpansion)
            if isExpanded {
                Divider().overlay(.white.opacity(0.08))
                editor
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            LinearGradient(colors: [DashboardPalette.panelTop, DashboardPalette.panel], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(isExpanded ? DashboardPalette.purple.opacity(0.55) : .white.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
    }

    private var summary: some View {
        HStack(spacing: 12) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.38))
                .frame(width: 16)

            Text(rule.comparison.title)
                .foregroundStyle(rule.comparison == .isEqual ? DashboardPalette.coral : DashboardPalette.pink)
                .fontWeight(.semibold)
            Text(rule.condition.title).foregroundStyle(.white.opacity(0.58))
            conditionValue
            Image(systemName: "arrow.right")
                .font(.caption).foregroundStyle(.white.opacity(0.28))
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
            Text("尚未设置").foregroundStyle(.white.opacity(0.30)).italic()
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
            Image(systemName: "app.dashed").foregroundStyle(.white.opacity(0.30))
            Text("选择应用").foregroundStyle(.white.opacity(0.30))
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
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
                                Text(application.bundleIdentifier).font(.caption2).foregroundStyle(.white.opacity(0.38))
                            }
                        } else {
                            Image(systemName: "plus.app.fill").foregroundStyle(DashboardPalette.purple)
                            Text("选择目标应用").fontWeight(.semibold)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.white.opacity(0.35))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 50)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

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
        }
        .padding(18)
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
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
        } else {
            TextField(rule.condition == .ip ? "例如 203.0.113.10" : "例如 203.0.113.0/24", text: $rule.value)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 11)
                .frame(minWidth: 190, minHeight: 38)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
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
        rule.condition == .ip ? "请输入有效的 IPv4 或 IPv6 地址" : "请输入有效的 CIDR 网段"
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
        let scalars = code.uppercased().unicodeScalars.compactMap { UnicodeScalar(127_397 + $0.value) }
        return String(String.UnicodeScalarView(scalars))
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
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "搜索正在运行的应用")
        }
        .frame(width: 560, height: 500)
        .task { applications = await ApplicationCatalog().runningApplications() }
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

private struct PlaceholderSettingsView: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: "hammer", description: Text(message))
            .navigationTitle(title)
    }
}
