//
//  InjectionTargetStore.swift
//  TrollFools
//
//  Created by Operit on 2025/10/16.
//

import Foundation

/// Persists the per-plug-in injection target chosen in the plug-in list.
///
/// Each app gets a small JSON side-car keyed by the plug-in file name, so the
/// list can render a badge and re-apply the pinned target when a plug-in is
/// enabled again.
final class InjectionTargetStore {
    static let shared = InjectionTargetStore()

    private let rootURL: URL

    private init() {
        let library = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask).first!
        rootURL = library
            .appendingPathComponent(Constants.gAppIdentifier, isDirectory: true)
            .appendingPathComponent("InjectionTargets", isDirectory: true)
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    private func fileURL(forBundleID bundleID: String) -> URL {
        rootURL.appendingPathComponent("\(bundleID).json")
    }

    // MARK: - Query

    func targets(forBundleID bundleID: String) -> [String: InjectionTarget] {
        let url = fileURL(forBundleID: bundleID)
        guard let data = try? Data(contentsOf: url) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: InjectionTarget].self, from: data)) ?? [:]
    }

    func target(forPlugInName name: String, bundleID: String) -> InjectionTarget? {
        targets(forBundleID: bundleID)[name]
    }

    // MARK: - Mutation

    func setTarget(_ target: InjectionTarget?, forPlugInName name: String, bundleID: String) {
        var map = targets(forBundleID: bundleID)
        if let target {
            map[name] = target
        } else {
            map.removeValue(forKey: name)
        }
        write(map, forBundleID: bundleID)
    }

    func removeAll(bundleID: String) {
        try? FileManager.default.removeItem(at: fileURL(forBundleID: bundleID))
    }

    // MARK: - Private

    private func write(_ map: [String: InjectionTarget], forBundleID bundleID: String) {
        guard let data = try? JSONEncoder().encode(map) else {
            return
        }
        try? data.write(to: fileURL(forBundleID: bundleID), options: .atomic)
    }
}
