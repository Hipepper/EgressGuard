import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $model.selectedSettingsSection) { section in
                Label(section.title, systemImage: section.symbolName).tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            switch model.selectedSettingsSection ?? .overview {
            case .overview: GeneralSettingsView(settings: $model.settings)
            case .rules: RulesSettingsView(settings: $model.settings)
            case .applications: ApplicationPickerView(model: model)
            case .notifications: PlaceholderSettingsView(title: "通知", message: "飞书 Webhook 与邮件通知将在通知阶段接入。")
            case .history: PlaceholderSettingsView(title: "历史记录", message: "检测与处置历史将在持久化阶段接入。")
            }
        }
    }
}

private struct GeneralSettingsView: View {
    @Binding var settings: GuardSettings

    var body: some View {
        Form {
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
