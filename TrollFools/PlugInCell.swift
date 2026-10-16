//
//  PlugInCell.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import QuickLook
import SwiftUI

private let gDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

struct PlugInCell: View {
    @EnvironmentObject var ejectList: EjectListModel
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @Binding var quickLookExport: URL?
    @State var isEnabled: Bool = false

    let plugIn: InjectedPlugIn

    init(_ plugIn: InjectedPlugIn, quickLookExport: Binding<URL?>) {
        self.plugIn = plugIn
        _quickLookExport = quickLookExport
    }

    @available(iOS 15, *)
    var highlightedName: AttributedString {
        let name = plugIn.url.lastPathComponent
        var attributedString = AttributedString(name)
        if let range = attributedString.range(of: ejectList.filter.searchKeyword, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributedString[range].foregroundColor = .accentColor
        }
        return attributedString
    }

    var iconName: String {
        let pathExt = plugIn.url.pathExtension.lowercased()
        if pathExt == "bundle" {
            return "archivebox"
        }
        if pathExt == "dylib" {
            return "bandage"
        }
        if pathExt == "framework" {
            return "shippingbox"
        }
        return "puzzlepiece"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Tapping the info area opens the injection-target picker.
            Button {
                ejectList.targetPickerPlugIn = plugIn
            } label: {
                labelContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // The switch keeps its original enable/disable behaviour.
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .onAppear {
            isEnabled = plugIn.isEnabled
        }
        .onChange(of: isEnabled) { value in
            ejectList.togglePlugIn(plugIn, isEnabled: value)
        }
        .contextMenu {
            Button {
                ejectList.targetPickerPlugIn = plugIn
            } label: {
                Label(NSLocalizedString("Injection Target…", comment: ""), systemImage: "target")
            }

            Divider()

            if #available(iOS 16.4, *) {
                ShareLink(item: plugIn.url) {
                    Label(NSLocalizedString("Export", comment: ""), systemImage: "square.and.arrow.up")
                }
            } else {
                Button {
                    exportPlugIn()
                } label: {
                    Label(NSLocalizedString("Export", comment: ""), systemImage: "square.and.arrow.up")
                }
            }

            Button {
                openInFilza()
            } label: {
                if isFilzaInstalled {
                    Label(NSLocalizedString("Show in Filza", comment: ""), systemImage: "scope")
                } else {
                    Label(NSLocalizedString("Filza (URL Scheme) Not Installed", comment: ""), systemImage: "xmark.octagon")
                }
            }
            .disabled(!isFilzaInstalled)
        }
    }

    @ViewBuilder
    private var labelContent: some View {
        HStack(spacing: 12) {
            if verticalSizeClass == .compact {
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                if #available(iOS 15, *) {
                    Text(highlightedName)
                        .font(.headline)
                        .lineLimit(2)
                } else {
                    Text(plugIn.url.lastPathComponent)
                        .font(.headline)
                        .lineLimit(2)
                }

                Text(gDateFormatter.string(from: plugIn.createdAt))
                    .font(.subheadline)
                    .lineLimit(1)

                targetChip
            }
        }
    }

    @ViewBuilder
    private var targetChip: some View {
        let title = plugIn.injectionTarget?.shortTitle
            ?? NSLocalizedString("Default (Automatic)", comment: "Injection target")
        let image = plugIn.injectionTarget?.systemImageName ?? "wand.and.stars"

        HStack(spacing: 4) {
            Image(systemName: image)
            Text(title)
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
        }
        .font(.caption2)
        .foregroundColor(.accentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
        )
        .lineLimit(1)
    }

    private func exportPlugIn() {
        quickLookExport = plugIn.url
    }

    var isFilzaInstalled: Bool { ejectList.app.appList?.isFilzaInstalled ?? false }

    private func openInFilza() {
        ejectList.app.appList?.openInFilza(plugIn.url)
    }
}