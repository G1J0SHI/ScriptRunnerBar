import SwiftUI

struct OutputPaneView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if !model.tabs.isEmpty {
                TabBarView()
                Divider()
            }

            Group {
                if let tab = model.selectedTab {
                    VStack(spacing: 0) {
                        RunHeaderView(tab: tab)
                        Divider()
                        OutputTextView(tab: tab)
                    }
                } else {
                    Text("Run a script to see its output here.")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
}

/// What ran and how it's going; kept out of the text so copying stays plain.
private struct RunHeaderView: View {
    let tab: OutputTab

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.command)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Text(tab.detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Label(tab.statusDescription, systemImage: tab.statusSymbol)
                .font(.caption)
                .foregroundStyle(tab.statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4))
        .accessibilityElement(children: .combine)
    }
}

/// Follows the bottom as output arrives, unless you've scrolled up.
private struct OutputTextView: View {
    let tab: OutputTab

    var body: some View {
        ScrollView {
            Text(tab.displayText)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        // Bottom-anchored for scrolling only: short output still sits at the top.
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .defaultScrollAnchor(.top, for: .alignment)
        // Fresh scroll state per tab.
        .id(tab.id)
    }
}

private struct TabBarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(model.tabs) { tab in
                    TabItemView(tab: tab, isSelected: tab.id == model.selectedTab?.id)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 30)
    }
}

private struct TabItemView: View {
    let tab: OutputTab
    let isSelected: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 4) {
            // Hidden from VoiceOver: the button's label already says the status.
            Image(systemName: tab.statusSymbol)
                .foregroundStyle(tab.statusColor)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)

            Button(tab.title) { model.select(tab) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .help("\(tab.title) \u{2014} \(tab.statusDescription)")
                .accessibilityLabel(tab.accessibilityTitle)

            Button { model.close(tab) } label: {
                Label("Close \(tab.title)", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 9, weight: .medium))
            }
            .buttonStyle(.plain)
            .frame(width: 14)
            .help("Close tab")
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .padding(.vertical, 3)
        .background(
            isSelected ? Color.accentColor.opacity(0.25) : .clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }
}
