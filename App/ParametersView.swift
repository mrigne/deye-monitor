import SwiftUI

/// Pick any parameter for the menu bar and/or the drop-down panel.
struct ParametersView: View {
    @EnvironmentObject var store: MonitorStore
    @State private var search = ""
    @State private var showRaw = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            selectedSummary
            TextField("Search parameters", text: $search)
                .textFieldStyle(.roundedBorder)
            List {
                Section("Inverter values") {
                    ForEach(filtered(store.catalog)) { row($0) }
                }
                Section {
                    if showRaw {
                        if store.rawParams.isEmpty {
                            Text("No data yet").foregroundStyle(.secondary)
                        }
                        ForEach(filtered(store.rawParams)) { row($0) }
                    }
                } header: {
                    HStack {
                        Text("Raw registers (unscaled)")
                        Spacer()
                        Button(showRaw ? "Hide" : "Show") { showRaw.toggle() }
                            .buttonStyle(.borderless)
                    }
                }
            }
            .listStyle(.inset)
            Text(store.summary == nil
                 ? "Values appear after the first successful read."
                 : "Values from the last read. Menu bar order follows the order you enable items; use ‹ › above to reorder.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(minWidth: 480, minHeight: 420)
    }

    private func filtered(_ list: [ParamDef]) -> [ParamDef] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return list }
        return list.filter { $0.title.lowercased().contains(q) || $0.id.lowercased().contains(q) }
    }

    private func row(_ p: ParamDef) -> some View {
        HStack(spacing: 10) {
            Image(systemName: p.symbol).frame(width: 18).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(p.title)
                Text(p.id).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            Text(p.display(store.value(p))).monospacedDigit().foregroundStyle(.secondary)
            Toggle("Menu bar", isOn: Binding(
                get: { store.menuBarParams.contains(p.id) },
                set: { store.setInMenuBar(p.id, $0) }))
            Toggle("Panel", isOn: Binding(
                get: { store.panelParams.contains(p.id) },
                set: { store.setInPanel(p.id, $0) }))
        }
        .toggleStyle(.checkbox)
        .font(.callout)
    }

    /// Current selections with reorder / remove controls.
    private var selectedSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            orderRow("Menu bar", ids: store.menuBarParams, inMenuBar: true)
            orderRow("Panel", ids: store.panelParams, inMenuBar: false)
        }
    }

    private func orderRow(_ title: String, ids: [String], inMenuBar: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary).frame(width: 62, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if ids.isEmpty { Text("nothing selected").font(.caption).foregroundStyle(.tertiary) }
                    ForEach(ids, id: \.self) { id in
                        HStack(spacing: 2) {
                            Button { store.move(id, inMenuBar: inMenuBar, by: -1) } label: { Image(systemName: "chevron.left") }
                            Text(store.param(id)?.title ?? id).lineLimit(1)
                            Button { store.move(id, inMenuBar: inMenuBar, by: 1) } label: { Image(systemName: "chevron.right") }
                            Button {
                                inMenuBar ? store.setInMenuBar(id, false) : store.setInPanel(id, false)
                            } label: { Image(systemName: "xmark") }
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                    }
                }
            }
        }
    }
}
