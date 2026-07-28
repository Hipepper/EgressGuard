import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(\.openSettings) private var openSettings
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: model.status.symbolName)
                    .font(.title2)
                    .foregroundStyle(model.status.color)
                VStack(alignment: .leading) {
                    Text(model.status.title).font(.headline)
                    Text(model.identity?.ip ?? "尚未取得出口 IP")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            if let identity = model.identity {
                LabeledContent("国家/地区", value: identity.countryName ?? identity.countryCode ?? "未知")
                LabeledContent("ASN", value: identity.asn ?? "未知")
                LabeledContent("运营商", value: identity.organization ?? "未知")
                LabeledContent("数据源", value: identity.provider)
                LabeledContent("最近检测", value: identity.checkedAt.formatted(date: .omitted, time: .standard))
            } else if let error = model.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let policyMessage = model.policyMessage {
                Label(policyMessage, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(model.status == .violation ? .red : .secondary)
            }

            HStack {
                Button("立即检测") { model.checkNow() }
                    .disabled(model.status == .checking)
                Button(model.status == .paused ? "恢复保护" : "暂停保护") {
                    model.status == .paused ? model.resumeProtection() : model.pauseProtection()
                }
                Spacer()
                Button("打开设置") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openSettings()
                }
            }

            Divider()
            Button("退出 EgressGuard") { NSApplication.shared.terminate(nil) }
        }
        .padding(16)
        .frame(width: 360)
    }
}
