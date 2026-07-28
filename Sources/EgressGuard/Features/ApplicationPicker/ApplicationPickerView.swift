import AppKit
import SwiftUI

struct ApplicationPickerView: View {
    @Bindable var model: AppModel
    @State private var isPickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("受保护应用").font(.title2.bold())
                    Text("出口不符合规则时，EgressGuard 会请求这些应用正常退出。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("选择应用…") { isPickerPresented = true }
            }
            .padding()

            Divider()

            if model.protectedApplications.isEmpty {
                ContentUnavailableView(
                    "尚未选择应用",
                    systemImage: "app.badge",
                    description: Text("点击“选择应用”即可按名称和图标选择，无需查找 Bundle ID。")
                )
            } else {
                List {
                    ForEach(model.protectedApplications) { application in
                        HStack(spacing: 12) {
                            ApplicationIcon(url: application.applicationURL)
                            VStack(alignment: .leading) {
                                Text(application.displayName)
                                Text(application.bundleIdentifier)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: model.removeApplications)
                }
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            RunningApplicationPicker { applications in
                model.addApplications(applications)
            }
        }
    }
}

private struct ApplicationIcon: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
            } else {
                Image(systemName: "app")
                    .resizable()
            }
        }
        .scaledToFit()
        .frame(width: 32, height: 32)
    }
}

private struct RunningApplicationPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var applications: [InstalledApplication] = []
    @State private var selection = Set<InstalledApplication.ID>()
    @State private var searchText = ""
    let onAdd: ([InstalledApplication]) -> Void

    private var filteredApplications: [InstalledApplication] {
        guard !searchText.isEmpty else { return applications }
        return applications.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            List(filteredApplications, selection: $selection) { application in
                HStack(spacing: 12) {
                    ApplicationIcon(url: application.url)
                    VStack(alignment: .leading) {
                        Text(application.displayName)
                        Text(application.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tag(application.id)
            }
            .searchable(text: $searchText, prompt: "搜索应用")

            Divider()
            HStack {
                Text("已选择 \(selection.count) 个应用").foregroundStyle(.secondary)
                Spacer()
                Button("取消") { dismiss() }
                Button("添加") {
                    onAdd(applications.filter { selection.contains($0.id) })
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection.isEmpty)
            }
            .padding()
        }
        .frame(width: 560, height: 460)
        .task { applications = await ApplicationCatalog().runningApplications() }
    }
}
