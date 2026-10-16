# Per-plug-in Injection Target

This adds the "choose the injection host" capability (ported from LCSign /
LoadController) to the TrollFools plug-in list.

## Injection targets

| Target | Meaning |
| --- | --- |
| Default (Automatic) | Original TrollFools behaviour — pick the best matching Mach-O. |
| Main Executable | Attach the plug-in to the app's main binary. |
| LoadControl | Route through the bundled substrate loader (anchors on the main executable). |
| Framework: … | Attach to a concrete Mach-O under `Frameworks/`. |
| Extension: … | Attach to an executable inside `PlugIns/*.appex`. |

## Where it lives

- `InjectionTarget.swift` — the `InjectionTarget` model (`Codable`, `Identifiable`,
  localized titles). Compiled into both the App and the CLI target.
- `InjectionTargetStore.swift` — per-app JSON side-car mapping plug-in file name →
  target, stored under `Library/<app-id>/InjectionTargets/<bundle-id>.json`.
- `InjectionTargetPickerSheet.swift` — the SwiftUI picker sheet.
- `InjectorV3` (`+Bundle`) — `TargetCandidate`, `availableInjectionTargets()`,
  `locateMachO(for:)`, `allFrameworkMachOs()`, `appExtensionExecutables()`,
  `runtimePathForInjectionTarget(_:)` and the `pinnedInjectionTarget` property.
- `InjectorV3+Inject` — `locateAvailableMachO()` honours the pinned target; the
  rpath written into app extensions walks back up (`@executable_path/../../Frameworks`).
- `InjectorV3+Eject` — `collectModifiedMachOs()` also scans app extensions.
- `InjectedPlugIn` — carries the pinned `injectionTarget`.
- `EjectListModel` / `PlugInCell` / `EjectListView` — list badge, picker
  presentation and the re-apply flow.

## Interaction

- Tap anywhere on a plug-in's info area (name / date / target chip) to open the
  injection-target picker. The trailing switch still enables/disables the plug-in.
- The same picker is also reachable from the long-press context menu
  ("Injection Target…").

## Behaviour

- A plug-in with no pinned target keeps the original automatic behaviour.
- Changing the target of an enabled plug-in ejects it from the previous host and
  re-injects it into the new one.
- Changing the target of a disabled plug-in only persists the choice; it is
  applied the next time the plug-in is enabled.
