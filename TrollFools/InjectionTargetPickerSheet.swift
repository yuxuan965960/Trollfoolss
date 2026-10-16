//
//  InjectionTargetPickerSheet.swift
//  TrollFools
//
//  Created by Operit on 2025/10/16.
//

import SwiftUI

/// Lets the user pin a plug-in to a concrete injection target:
/// the main executable, a framework, an app extension, or LoadControl.
struct InjectionTargetPickerSheet: View {
    let plugInName: String
    let candidates: [InjectorV3.TargetCandidate]
    let selected: InjectionTarget?
    let onSelect: (InjectionTarget?) -> Void

    @Environment(\.presentationMode) private var presentationMode

    private var frameworks: [InjectorV3.TargetCandidate] {
        candidates.filter {
            if case .framework = $0.target { return true }
            return false
        }
    }

    private var extensions: [InjectorV3.TargetCandidate] {
        candidates.filter {
            if case .appExtension = $0.target { return true }
            return false
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    row(
                        title: NSLocalizedString("Default (Automatic)", comment: "Injection target"),
                        subtitle: NSLocalizedString("Let TrollFools pick the best matching Mach-O.", comment: "Injection target"),
                        systemImage: "wand.and.stars",
                        isSelected: selected == nil
                    ) {
                        onSelect(nil)
                        dismiss()
                    }
                } footer: {
                    Text(plugInName)
                        .font(.footnote)
                }

                Section {
                    row(
                        title: NSLocalizedString("Main Executable", comment: "Injection target"),
                        subtitle: NSLocalizedString("Attach the plug-in to the app binary.", comment: "Injection target"),
                        systemImage: "app.dashed",
                        isSelected: selected == .mainExecutable
                    ) {
                        onSelect(.mainExecutable)
                        dismiss()
                    }

                    row(
                        title: NSLocalizedString("LoadControl", comment: "Injection target"),
                        subtitle: NSLocalizedString("Route through the bundled LoadControl loader.", comment: "Injection target"),
                        systemImage: "point.3.connected.trianglepath.dotted",
                        isSelected: selected == .loadControl
                    ) {
                        onSelect(.loadControl)
                        dismiss()
                    }
                }

                if !frameworks.isEmpty {
                    Section(header: Text(NSLocalizedString("Frameworks", comment: "Injection target"))) {
                        ForEach(frameworks) { candidate in
                            row(
                                title: candidate.target.localizedTitle,
                                subtitle: candidate.machOURL.lastPathComponent,
                                systemImage: "shippingbox",
                                isSelected: selected == candidate.target
                            ) {
                                onSelect(candidate.target)
                                dismiss()
                            }
                        }
                    }
                }

                if !extensions.isEmpty {
                    Section(header: Text(NSLocalizedString("Extensions", comment: "Injection target"))) {
                        ForEach(extensions) { candidate in
                            row(
                                title: candidate.target.localizedTitle,
                                subtitle: candidate.machOURL.lastPathComponent,
                                systemImage: "puzzlepiece.extension",
                                isSelected: selected == candidate.target
                            ) {
                                onSelect(candidate.target)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("Injection Target", comment: "Injection target"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private func row(
        title: String,
        subtitle: String?,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}