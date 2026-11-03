import SwiftUI

struct ExtensionSettingsView: View {
    @ObservedObject var extensionStore = ExtensionStore.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var newFilterName: String = ""
    @State private var newFilterURL: String = ""
    @State private var showAddFilterSheet: Bool = false

    var body: some View {
        NavigationView {
            List {
                // Section 1: Danh sách bộ lọc AdGuard
                Section(header: Text("Bộ lọc AdGuard (Filter Lists)")) {
                    ForEach(extensionStore.filters) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("\(item.ruleCount) quy tắc • \(item.url)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { item.isEnabled },
                                set: { _ in extensionStore.toggleFilter(id: item.id) }
                            ))
                            .labelsHidden()
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: extensionStore.deleteFilter)

                    Button(action: { showAddFilterSheet = true }) {
                        Label("Thêm bộ lọc URL tùy chỉnh (.txt)", systemImage: "plus.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }

                // Section 2: Tiện ích mở rộng / Scriptlets (Tampermonkey style)
                Section(header: Text("Tiện ích UserScripts / Scriptlets")) {
                    ForEach(extensionStore.userScripts) { script in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(script.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Chạy ngầm trên mọi frame & video player")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { script.isEnabled },
                                set: { _ in extensionStore.toggleScript(id: script.id) }
                            ))
                            .labelsHidden()
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Section 3: Cập nhật & Làm mới
                Section {
                    Button(action: {
                        AdBlockEngine.shared.compileRules()
                    }) {
                        HStack {
                            Spacer()
                            Text("Cập nhật lại quy tắc bộ lọc")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 0.18, green: 0.82, blue: 0.35))
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Tiện ích AdGuard")
            .navigationBarItems(trailing: Button("Xong") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showAddFilterSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("Thông tin bộ lọc")) {
                            TextField("Tên bộ lọc (vd: Chặn qc cá nhân)", text: $newFilterName)
                            TextField("URL danh sách (.txt / EasyList)", text: $newFilterURL)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                        }
                        Button("Lưu bộ lọc") {
                            guard !newFilterURL.isEmpty else { return }
                            extensionStore.addCustomFilter(
                                name: newFilterName.isEmpty ? "Bộ lọc tùy chỉnh" : newFilterName,
                                url: newFilterURL
                            )
                            newFilterName = ""
                            newFilterURL = ""
                            showAddFilterSheet = false
                        }
                    }
                    .navigationTitle("Thêm bộ lọc mới")
                    .navigationBarItems(leading: Button("Hủy") { showAddFilterSheet = false })
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
