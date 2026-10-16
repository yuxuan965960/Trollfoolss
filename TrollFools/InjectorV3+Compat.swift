//
//  InjectorV3+Compat.swift
//  TrollFools
//
//  Created by Operit on 2025/10/16.
//

import CocoaLumberjackSwift
import Foundation

extension InjectorV3 {
    // MARK: - Constants

    /// System symbols that only exist on newer OS releases.
    ///
    /// A payload built with a newer deployment target may reference one of
    /// them. Because such a reference is a hard (non-weak) import, dyld aborts
    /// the whole host process at launch:
    ///
    ///     Symbol not found: (_objc_claimAutoreleasedReturnValue)
    ///     Referenced from: '.../LPDCrowdsourceAppStore.app/Frameworks/alivcffmpeg.dylib'
    ///     Expected in: '/usr/lib/libobjc.A.dylib'
    ///
    /// The value is an ordered list of semantically compatible replacement
    /// symbols. The first entry that (a) exists on the current OS and (b) fits
    /// into the original name's slot in the string store is written in place.
    static let incompatibleSystemSymbols: [String: [String]] = [
        // Newer ARC "claim" entry points. `objc_claimAutoreleasedReturnValue`
        // was introduced after iOS 15 / macOS 12. The classic counterparts below
        // are exported by every version of libobjc and are a safe superset
        // (they may over-retain at worst, never over-release).
        "_objc_claimAutoreleasedReturnValue": [
            "_objc_retainAutoreleasedReturnValue",
            "_objc_retain",
        ],
        "_objc_unsafeClaimAutoreleasedReturnValue": [
            "_objc_retainAutoreleasedReturnValue",
            "_objc_retain",
        ],
    ]

    private static let lcSymtab: UInt32 = 0x2
    private static let lcDyldChainedFixups: UInt32 = 0x8000_0034

    // MARK: - Instance Methods

    /// Repairs a payload that hard-links system symbols missing from the
    /// current OS, so it no longer makes the host app abort at launch.
    ///
    /// Must be called **before** the payload is (re)signed.
    @discardableResult
    func repairIncompatibleSymbols(in assetURL: URL) -> Bool {
        guard repairsIncompatibleSymbols else {
            return false
        }

        let machOURL: URL
        if checkIsBundle(assetURL) {
            guard let executableURL = try? locateExecutableInBundle(assetURL) else {
                return false
            }
            machOURL = executableURL
        } else {
            machOURL = assetURL
        }

        guard isMachO(machOURL) else {
            return false
        }

        let repairs: [String]
        do {
            repairs = try patchMissingSymbols(ofMachOAt: machOURL)
        } catch {
            DDLogError("Failed to repair symbols of \(machOURL.lastPathComponent): \(error)", ddlog: logger)
            return false
        }

        guard !repairs.isEmpty else {
            return false
        }

        DDLogWarn("Repaired incompatible symbols in \(machOURL.lastPathComponent): \(repairs.joined(separator: ", "))", ddlog: logger)

        // The bytes just changed, so the previous signature is stale.
        try? cmdPseudoSign(machOURL, force: true)
        return true
    }

    // MARK: - Mach-O Patching

    fileprivate func patchMissingSymbols(ofMachOAt url: URL) throws -> [String] {
        var bytes = [UInt8](try Data(contentsOf: url))
        var applied: [String] = []

        let isFatBigEndian = bytes.count >= 8 &&
            bytes[0] == 0xCA && bytes[1] == 0xFE && bytes[2] == 0xBA && bytes[3] == 0xBE
        let isFatLittleEndian = bytes.count >= 8 &&
            bytes[0] == 0xBE && bytes[1] == 0xBA && bytes[2] == 0xFE && bytes[3] == 0xCA

        if isFatBigEndian || isFatLittleEndian {
            let nfat = Int(isFatBigEndian
                ? Self.readU32BE(bytes, 4)
                : Self.readU32LE(bytes, 4))
            for index in 0 ..< nfat {
                let entry = 8 + index * 20
                guard entry + 20 <= bytes.count else {
                    break
                }
                let archOffset = Int(isFatBigEndian
                    ? Self.readU32BE(bytes, entry + 8)
                    : Self.readU32LE(bytes, entry + 8))
                applied.append(contentsOf: Self.patchSlice(&bytes, at: archOffset))
            }
        } else {
            applied.append(contentsOf: Self.patchSlice(&bytes, at: 0))
        }

        if !applied.isEmpty {
            try Data(bytes).write(to: url, options: .atomic)
        }

        return applied
    }

    fileprivate static func patchSlice(_ bytes: inout [UInt8], at sliceOffset: Int) -> [String] {
        guard sliceOffset >= 0, sliceOffset + 32 <= bytes.count else {
            return []
        }

        let magic = readU32LE(bytes, sliceOffset)
        let is64: Bool
        switch magic {
        case 0xFEEDFACF: // MH_MAGIC_64
            is64 = true
        case 0xFEEDFACE: // MH_MAGIC
            is64 = false
        default:
            return []
        }

        let headerSize = is64 ? 32 : 28
        let ncmds = Int(readU32LE(bytes, sliceOffset + 16))

        var applied: [String] = []
        var cursor = sliceOffset + headerSize
        var index = 0
        while index < ncmds, cursor + 8 <= bytes.count {
            let cmd = readU32LE(bytes, cursor)
            let cmdSize = Int(readU32LE(bytes, cursor + 4))

            if cmd == lcSymtab, cursor + 24 <= bytes.count {
                // struct symtab_command { cmd, cmdsize, symoff, nsyms, stroff, strsize }
                let stroff = Int(readU32LE(bytes, cursor + 16))
                let strsize = Int(readU32LE(bytes, cursor + 20))
                applied.append(contentsOf: patchStringStore(
                    &bytes,
                    base: sliceOffset + stroff,
                    size: strsize
                ))
            } else if cmd == lcDyldChainedFixups, cursor + 16 <= bytes.count {
                // struct linkedit_data_command { cmd, cmdsize, dataoff, datasize }
                let dataoff = Int(readU32LE(bytes, cursor + 8))
                let datasize = Int(readU32LE(bytes, cursor + 12))
                // dyld_chained_fixups_header { fixups_version, starts_offset,
                //   imports_offset, symbols_offset, ... } lives at `dataoff`.
                let headerOffset = sliceOffset + dataoff
                if headerOffset + 16 <= bytes.count {
                    let symbolsOffset = Int(readU32LE(bytes, headerOffset + 12))
                    if symbolsOffset >= 0, symbolsOffset < datasize {
                        // Chained-fixup imports address their names through this
                        // dedicated symbol string pool (relative to `dataoff`).
                        applied.append(contentsOf: patchStringStore(
                            &bytes,
                            base: sliceOffset + dataoff + symbolsOffset,
                            size: datasize - symbolsOffset
                        ))
                    }
                }
            }

            guard cmdSize > 0 else {
                break
            }
            cursor += cmdSize
            index += 1
        }

        return applied
    }

    /// Rewrites the payload's symbol string store in place.
    ///
    /// Renaming the string is enough for every binding mechanism, because they
    /// all address a name through its null-terminated slot in a string store:
    ///
    /// * classic two-level binds / `LC_DYLD_INFO*` and the `LC_SYMTAB` symbol
    ///   table (`stroff`), and
    /// * chained-fixup imports (`LC_DYLD_CHAINED_FIXUPS` → `symbols_offset`).
    ///
    /// The replacement is always shorter than (or equal to) the original, so
    /// the store size never changes and no other offset is invalidated.
    fileprivate static func patchStringStore(
        _ bytes: inout [UInt8],
        base: Int,
        size: Int
    ) -> [String] {
        guard base >= 0, size > 0, base + size <= bytes.count else {
            return []
        }

        var applied: [String] = []
        let end = base + size

        for (missing, replacements) in incompatibleSystemSymbols {
            // Nothing to do when the current OS already exports the symbol.
            guard !symbolExistsOnCurrentSystem(missing) else {
                continue
            }

            guard let replacement = replacements.first(where: {
                $0.utf8.count <= missing.utf8.count && symbolExistsOnCurrentSystem($0)
            }) else {
                continue
            }

            let needle = Array(missing.utf8) + [0]
            let replacementBytes = Array(replacement.utf8) + [0]

            var cursor = base
            while cursor + needle.count <= end {
                let atStringBoundary = cursor == base || bytes[cursor - 1] == 0
                if atStringBoundary, bytes[cursor ..< cursor + needle.count].elementsEqual(needle) {
                    for (offset, byte) in replacementBytes.enumerated() {
                        bytes[cursor + offset] = byte
                    }
                    applied.append("\(missing) → \(replacement)")
                    cursor += needle.count
                } else {
                    cursor += 1
                }
            }
        }

        return applied
    }

    /// Whether the running OS exports `symbol` (Mach-O C name, i.e. with the
    /// leading underscore).
    fileprivate static func symbolExistsOnCurrentSystem(_ symbol: String) -> Bool {
        let name = symbol.hasPrefix("_") ? String(symbol.dropFirst()) : symbol
        return dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) != nil
    }

    // MARK: - Byte Helpers

    fileprivate static func readU32LE(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= bytes.count else {
            return 0
        }
        return UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }

    fileprivate static func readU32BE(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= bytes.count else {
            return 0
        }
        return (UInt32(bytes[offset]) << 24)
            | (UInt32(bytes[offset + 1]) << 16)
            | (UInt32(bytes[offset + 2]) << 8)
            | UInt32(bytes[offset + 3])
    }
}
