import SwiftUI

// MARK: - Sidebar

/// One sidebar row: a tinted icon chip, a single-line title, and an optional
/// trailing status dot (a provider that is on).
struct SettingsChipLabel: View {
    let title: String
    let systemImage: String
    var tint: Color
    var statusDot: Color?
    var dimmed = false

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.gradient)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .accessibilityHidden(true)
            Text(title)
                .lineLimit(1)
                .foregroundStyle(dimmed ? Color.secondary : Color.primary)
            Spacer(minLength: 4)
            if let statusDot {
                Circle()
                    .fill(statusDot)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusDot != nil ? "\(title), on" : title)
        .accessibilityHint("Select to view this section.")
    }
}

struct SettingsSidebarSearchField: View {
    @Binding var text: String
    @Binding var sort: SettingsSidebarSort

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search settings", text: $text)
                .textFieldStyle(.plain)
                .accessibilityLabel("Search settings")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(SettingsSidebarSort.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Sort settings list")
        }
        .padding(6)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

// MARK: - Detail primitives

/// The flat replacement for `Form { … }.formStyle(.grouped)`. No in-pane title
/// block — the window title carries the pane name.
struct SettingsForm<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .padding(.top, 8)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background)
    }
}

struct SettingsSection<Content: View>: View {
    var title: String?
    var trailingCaption: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    if let trailingCaption {
                        Text(trailingCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .accessibilityAddTraits(.isHeader)
            }
            _VariadicView.Tree(SettingsDividedRows()) { content }
        }
        .padding(.top, 14)
    }
}

private struct SettingsDividedRows: _VariadicView_MultiViewRoot {
    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        let lastID = children.last?.id
        VStack(alignment: .leading, spacing: 0) {
            ForEach(children) { child in
                child
                if child.id != lastID {
                    Divider().padding(.leading, 20)
                }
            }
        }
    }
}

/// Base row: title (+ optional caption beneath) on the left, a trailing control.
struct SettingsRow<Control: View>: View {
    let title: String
    var caption: String?
    var titleTint: Color?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(titleTint ?? .primary)
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control.layoutPriority(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}

struct SettingsValueRow: View {
    let title: String
    var caption: String?
    let value: String

    var body: some View {
        SettingsRow(title: title, caption: caption) {
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityLabel("\(title), \(value)")
    }
}

struct SettingsToggleRow: View {
    let title: String
    var caption: String?
    let isOn: Binding<Bool>
    var isEnabled = true

    init(_ title: String, caption: String? = nil, isOn: Binding<Bool>, isEnabled: Bool = true) {
        self.title = title
        self.caption = caption
        self.isOn = isOn
        self.isEnabled = isEnabled
    }

    /// Get/set variant for stores whose "enabled" flag is not a plain `Binding`.
    init(_ title: String, caption: String? = nil, isEnabled: Bool = true,
         get: @escaping () -> Bool, set: @escaping (Bool) -> Void) {
        self.title = title
        self.caption = caption
        self.isEnabled = isEnabled
        self.isOn = Binding(get: get, set: set)
    }

    var body: some View {
        SettingsRow(title: title, caption: caption) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(!isEnabled)
        }
    }
}

struct SettingsPickerRow<SelectionValue: Hashable, Options: View>: View {
    let title: String
    var caption: String?
    let selection: Binding<SelectionValue>
    @ViewBuilder var options: Options

    var body: some View {
        SettingsRow(title: title, caption: caption) {
            Picker("", selection: selection) { options }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
        }
    }
}

struct SettingsButtonRow: View {
    let title: String
    var caption: String?
    var role: ButtonRole?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button(role: role, action: action) {
                Text(title)
                    .foregroundStyle(role == .destructive ? Color.red : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
    }
}

struct SettingsLinkRow: View {
    let title: String
    let systemImage: String
    let destination: URL

    var body: some View {
        HStack(spacing: 12) {
            Link(destination: destination) {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
    }
}

struct SettingsInfoRow: View {
    let text: String
    var systemImage: String
    var tint: Color?

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.callout)
        .foregroundStyle(tint ?? Color.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

/// Standalone explanatory paragraph between sections — never inside a box.
struct SettingsNote: View {
    let text: String
    var tint: Color?

    init(_ text: String, tint: Color? = nil) {
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(tint ?? Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }
}

// MARK: - Provider detail header

struct SettingsProviderCard<Trailing: View>: View {
    let provider: UsageProvider
    let statusLine: String
    var isOn: Bool
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill((provider == .codex ? Color.green : Color.orange).gradient)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: provider.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.title).font(.headline)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(provider.title), \(isOn ? "on" : "off"). \(statusLine)")
    }
}
