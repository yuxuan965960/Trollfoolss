//
//  InjectedPlugIn.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import Foundation

struct InjectedPlugIn: Equatable, Identifiable, Hashable {
    let id: String
    let url: URL
    let createdAt: Date
    let isEnabled: Bool

    /// The injection host this plug-in is pinned to, or `nil` to let
    /// TrollFools pick the best matching Mach-O automatically.
    let injectionTarget: InjectionTarget?

    init(url: URL, isEnabled: Bool, injectionTarget: InjectionTarget? = nil) {
        self.id = url.absoluteString
        self.url = url
        self.createdAt = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        self.isEnabled = isEnabled
        self.injectionTarget = injectionTarget
    }
}