import SwiftUI
import AppKit

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $model.selectedSettingsSection)
                .frame(width: 224)
            Divider()
            Group {
                switch model.selectedSettingsSection ?? .overview {
                case .overview: GeneralSettingsView(settings: $model.settings)
                case .rules: RulesSettingsView(settings: $model.settings)
                case .applications: ApplicationPickerView(model: model)
                case .notifications: PlaceholderSettingsView(title: "通知", message: "飞书 Webhook 与邮件通知将在通知阶段接入。")
                case .history: PlaceholderSettingsView(title: "历史记录", message: "检测与处置历史将在持久化阶段接入。")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 42)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .background(.ultraThinMaterial)
    }
}

private struct SettingsSidebar: View {
    @Binding var selection: SettingsSection?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("EgressGuard").font(.headline)
                    Text("出口安全控制台").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)

            VStack(spacing: 5) {
                ForEach(SettingsSection.allCases) { section in
                    Button { selection = section } label: {
                        HStack(spacing: 11) {
                            Image(systemName: section.symbolName)
                                .font(.system(size: 14, weight: .medium)).frame(width: 20)
                            Text(section.title).fontWeight(selection == section ? .semibold : .regular)
                            Spacer()
                        }
                        .foregroundStyle(selection == section ? Color.white : Color.primary)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background {
                            if selection == section {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(LinearGradient(
                                        colors: [Color(red: 0.05, green: 0.47, blue: 0.78), Color(red: 0.05, green: 0.68, blue: 0.70)],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .shadow(color: .cyan.opacity(0.18), radius: 8, y: 2)
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
                Text("本地保护服务").font(.caption).foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .padding(.top, 56)
        .background(.regularMaterial)
    }
}

private struct GeneralSettingsView: View {
    @Binding var settings: GuardSettings

    var body: some View {
        Form {
            Section("菜单栏显示") {
                Picker("IP 展示方式", selection: $settings.menuBarIPDisplayMode) {
                    ForEach(MenuBarIPDisplayMode.allCases) { mode in
                        HStack {
                            Text(mode.title)
                            Text(mode.example).foregroundStyle(.secondary)
                        }
                        .tag(mode)
                    }
                }
                Toggle("显示出口国家/地区旗帜", isOn: $settings.showsCountryFlagInMenuBar)
                    .disabled(settings.menuBarIPDisplayMode == .iconOnly)
                Text(settings.menuBarIPDisplayMode == .iconOnly
                     ? "仅显示保护正常、已暂停或异常三类状态图标。"
                     : "IPv4 会显示在菜单栏；只有 IPv6 时仅保留状态图标。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("保护") {
                Toggle("启用出口保护", isOn: $settings.isProtectionEnabled)
                    .disabled(!settings.hasPolicyConstraints)
                if !settings.hasPolicyConstraints {
                    Label("请先在“保护规则”中添加至少一条规则", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Stepper("检测间隔：\(Int(settings.checkInterval)) 秒", value: $settings.checkInterval, in: 15...1_800, step: 15)
                Stepper("请求超时：\(Int(settings.requestTimeout)) 秒", value: $settings.requestTimeout, in: 1...30)
                Stepper("启动宽限期：\(Int(settings.startupGracePeriod)) 秒", value: $settings.startupGracePeriod, in: 0...300, step: 10)
            }
            Section("确认阈值") {
                Stepper("连续异常 \(settings.violationThreshold) 次后处置", value: $settings.violationThreshold, in: 1...10)
                Stepper("连续正常 \(settings.recoveryThreshold) 次后恢复", value: $settings.recoveryThreshold, in: 1...10)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("常规")
    }
}

private struct RulesSettingsView: View {
    @Binding var settings: GuardSettings
    @State private var isCountryPickerPresented = false

    var body: some View {
        Form {
            Section {
                Text("同一类型中的多个值满足任意一个即可；不同类型需要同时满足。")
                    .foregroundStyle(.secondary)
            }
            RuleValuesEditor(
                title: "固定出口 IP",
                description: "适合公司或代理提供固定公网 IP 的场景。",
                placeholder: "例如 203.0.113.10",
                kind: .ip,
                values: $settings.allowedIPs
            )
            RuleValuesEditor(
                title: "允许的网段",
                description: "允许一个完整的 IPv4 或 IPv6 地址范围。",
                placeholder: "例如 203.0.113.0/24",
                kind: .cidr,
                values: $settings.allowedCIDRs
            )
            Section("允许的国家/地区") {
                ForEach(settings.allowedCountryCodes, id: \.self) { code in
                    HStack {
                        Text(CountryOption.flag(for: code))
                        Text(Locale.current.localizedString(forRegionCode: code) ?? code)
                        Spacer()
                        Text(code).foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            settings.allowedCountryCodes.removeAll { $0 == code }
                        } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain)
                    }
                }
                Button("选择国家或地区…") { isCountryPickerPresented = true }
            }
            RuleValuesEditor(
                title: "允许的 ASN",
                description: "高级选项。适合出口运营商拥有固定自治系统编号的场景。",
                placeholder: "例如 AS45102",
                kind: .asn,
                values: $settings.allowedASNs
            )
        }
        .formStyle(.grouped)
        .navigationTitle("保护规则")
        .sheet(isPresented: $isCountryPickerPresented) {
            CountryPicker(selection: $settings.allowedCountryCodes)
        }
    }
}

private struct RuleValuesEditor: View {
    enum Kind {
        case ip, cidr, asn

        func isValid(_ value: String) -> Bool {
            switch self {
            case .ip: return IPNetwork.isValidAddress(value)
            case .cidr: return (try? IPNetwork(value)) != nil
            case .asn:
                let normalized = value.uppercased().hasPrefix("AS") ? String(value.dropFirst(2)) : value
                return !normalized.isEmpty && normalized.allSatisfy(\.isNumber)
            }
        }

        func normalize(_ value: String) -> String {
            switch self {
            case .asn: value.uppercased().hasPrefix("AS") ? value.uppercased() : "AS\(value)"
            case .ip, .cidr: value
            }
        }
    }

    let title: String
    let description: String
    let placeholder: String
    let kind: Kind
    @Binding var values: [String]
    @State private var draft = ""
    @State private var validationMessage: String?

    var body: some View {
        Section(title) {
            Text(description).font(.caption).foregroundStyle(.secondary)
            ForEach(values, id: \.self) { value in
                HStack {
                    Text(value)
                    Spacer()
                    Button(role: .destructive) { values.removeAll { $0 == value } } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                TextField(placeholder, text: $draft)
                    .onSubmit(addValue)
                Button("添加", action: addValue).disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func addValue() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        guard kind.isValid(value) else {
            validationMessage = "格式不正确，请参考输入框中的示例"
            return
        }
        let normalized = kind.normalize(value)
        guard !values.contains(normalized) else {
            validationMessage = "这条规则已经存在"
            return
        }
        values.append(normalized)
        draft = ""
        validationMessage = nil
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

private struct CountryPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: [String]
    @State private var searchText = ""

    private var filteredCountries: [CountryOption] {
        guard !searchText.isEmpty else { return CountryOption.all }
        return CountryOption.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            List(filteredCountries) { country in
                Button {
                    if selection.contains(country.code) {
                        selection.removeAll { $0 == country.code }
                    } else {
                        selection.append(country.code)
                    }
                } label: {
                    HStack {
                        Text(CountryOption.flag(for: country.code))
                        Text(country.name)
                        Spacer()
                        Text(country.code).foregroundStyle(.secondary)
                        if selection.contains(country.code) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "搜索国家、地区或代码")
            Divider()
            HStack {
                Text("已选择 \(selection.count) 个").foregroundStyle(.secondary)
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 520, height: 560)
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
