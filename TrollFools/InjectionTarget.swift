//
//  InjectionTarget.swift
//  TrollFools
//
//  Created by Operit on 2025/10/16.
//

import Foundation

/// Which Mach-O a plug-in should be attached to.
///
/// The model mirrors the injection-target selection found in LCSign
/// (LoadController): a plug-in may be pinned to the app's main executable,
/// a concrete framework inside `Frameworks/`, an app extension inside
/// `PlugIns/`, or routed through a bundled `LoadControl` loader.
enum InjectionTarget: Hashable {
    /// The main executable of the app bundle (「主程序」).
    case mainExecutable
    /// A concrete Mach-O inside `Frameworks/`.
    /// - Parameter name: bundle or file name, e.g. `ProtobufLite.framework` or `Foo.dylib`.
    case framework(String)
    /// Route through the bundled `LoadControl` loader instead of touching the
    /// main binary directly.
    case loadControl
    /// A plug-in extension inside `PlugIns/`.
    /// - Parameter name: bundle name, e.g. `MyWidget.appex`.
    case appExtension(String)
}

// MARK: - Codable

extension InjectionTarget: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case name
    }

    private enum Kind: String, Codable {
        case mainExecutable
        case framework
        case loadControl
        case appExtension
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .mainExecutable:
            self = .mainExecutable
        case .framework:
            self = .framework(try container.decode(String.self, forKey: .name))
        case .loadControl:
            self = .loadControl
        case .appExtension:
            self = .appExtension(try container.decode(String.self, forKey: .name))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .mainExecutable:
            try container.encode(Kind.mainExecutable, forKey: .kind)
        case let .framework(name):
            try container.encode(Kind.framework, forKey: .kind)
            try container.encode(name, forKey: .name)
        case .loadControl:
            try container.encode(Kind.loadControl, forKey: .kind)
        case let .appExtension(name):
            try container.encode(Kind.appExtension, forKey: .kind)
            try container.encode(name, forKey: .name)
        }
    }
}

// MARK: - Presentation

extension InjectionTarget: Identifiable {
    var id: String {
        switch self {
        case .mainExecutable: return "main"
        case let .framework(name): return "framework:\(name)"
        case .loadControl: return "loadControl"
        case let .appExtension(name): return "appExtension:\(name)"
        }
    }

    /// Full, human readable name shown in the picker.
    var localizedTitle: String {
        switch self {
        case .mainExecutable:
            return NSLocalizedString("Main Executable", comment: "Injection target")
        case let .framework(name):
            return String(format: NSLocalizedString("Framework: %@", comment: "Injection target"), name)
        case .loadControl:
            return NSLocalizedString("LoadControl", comment: "Injection target")
        case let .appExtension(name):
            return String(format: NSLocalizedString("Extension: %@", comment: "Injection target"), name)
        }
    }

    /// Compact name used by the plug-in list badge.
    var shortTitle: String {
        switch self {
        case .mainExecutable:
            return NSLocalizedString("Main", comment: "Injection target")
        case .framework:
            return NSLocalizedString("Framework", comment: "Injection target")
        case .loadControl:
            return NSLocalizedString("LoadControl", comment: "Injection target")
        case .appExtension:
            return NSLocalizedString("Extension", comment: "Injection target")
        }
    }

    var systemImageName: String {
        switch self {
        case .mainExecutable: return "app.dashed"
        case .framework: return "shippingbox"
        case .loadControl: return "point.3.connected.trianglepath.dotted"
        case .appExtension: return "puzzlepiece.extension"
        }
    }
}
