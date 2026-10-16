//
//  CmdInject.swift
//  TrollFools
//
//  Created by Rachel on 10/3/2025.
//

import ArgumentParser
import Foundation

struct CmdInject: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "inject",
        abstract: "Inject a persistent payload to a target application"
    )

    @Argument(help: "The bundle identifier of the application.")
    var bundleIdentifier: String

    @Option(name: [.customLong("path"), .customShort("p")], parsing: .upToNextOption, help: "The path of the plugin. A .dylib / .framework / .bundle / .deb / .zip package is accepted.")
    var pluginPaths: [String]

    @Option(name: [.customLong("target")], help: "Pin the plug-in to a concrete host: auto | main | loadcontrol | framework:<name> | extension:<name>. Defaults to auto.")
    var target: String?

    @Flag(name: [.customLong("fast")], help: "Use fast injection strategy.")
    var fastInjection: Bool = false

    @Flag(name: [.customLong("weak")], help: "Use weak reference.")
    var weakReference: Bool = false

    func run() throws {
        guard let app = LSApplicationProxy(forIdentifier: bundleIdentifier),
              let appID = app.applicationIdentifier(),
              let bundleURL = app.bundleURL()
        else {
            throw ArgumentParser.ValidationError("The specified application does not exist.")
        }
        try pluginPaths.forEach {
            guard FileManager.default.fileExists(atPath: $0) else {
                throw ArgumentParser.ValidationError("This plugin does not exist: \($0)")
            }
        }
        let pluginURLs = pluginPaths.compactMap { URL(fileURLWithPath: $0) }
        let injector = try InjectorV3(bundleURL, loggerType: .os)
        if injector.appID.isEmpty {
            injector.appID = appID
        }
        if injector.teamID.isEmpty {
            if let teamID = app.teamID() {
                injector.teamID = teamID
            } else {
                injector.teamID = "0000000000"
            }
        }
        injector.useWeakReference = weakReference
        injector.injectStrategy = fastInjection ? .fast : .lexicographic
        injector.pinnedInjectionTarget = try Self.parseInjectionTarget(target)
        try injector.inject(pluginURLs, shouldPersist: false)
    }

    /// Parses the `--target` value into a concrete `InjectionTarget`.
    ///
    /// Accepted forms:
    /// - `auto` (or empty) — keep the automatic best-match behaviour
    /// - `main` — the app's main executable (「主程序」)
    /// - `loadcontrol` — route through the bundled LoadControl loader
    /// - `framework:<name>` — a concrete Mach-O under `Frameworks/`
    ///   (e.g. `framework:OpenSSL.framework` or `framework:Foo.dylib`)
    /// - `extension:<name>` — a plug-in under `PlugIns/`
    ///   (e.g. `extension:LCShareExtension.appex`)
    private static func parseInjectionTarget(_ raw: String?) throws -> InjectionTarget? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let lowered = raw.lowercased()
        switch lowered {
        case "auto", "default", "automatic", "none":
            return nil
        case "main", "mainexecutable":
            return .mainExecutable
        case "loadcontrol", "load-controller", "load_control":
            return .loadControl
        default:
            break
        }

        if let value = value(of: "framework", in: raw) {
            guard !value.isEmpty else {
                throw ArgumentParser.ValidationError("Missing framework name, expected framework:<name>.")
            }
            return .framework(value)
        }

        if let value = value(of: "extension", in: raw) ?? value(of: "appex", in: raw) {
            guard !value.isEmpty else {
                throw ArgumentParser.ValidationError("Missing extension name, expected extension:<name>.")
            }
            return .appExtension(value)
        }

        // A bare value is treated as a framework / dylib name.
        return .framework(raw)
    }

    private static func value(of key: String, in raw: String) -> String? {
        let prefix = key.lowercased() + ":"
        guard raw.lowercased().hasPrefix(prefix) else {
            return nil
        }
        return String(raw.dropFirst(prefix.count))
    }
}