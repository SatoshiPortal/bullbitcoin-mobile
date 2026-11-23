# Silent Payments

`package:silent/silent.dart` exposes the account capability, owned values and failures, and typed wallet and settings navigation. The host mounts the feature once through `package:silent/setup.dart`, supplies the exact-network default Bitcoin fingerprint and existing navigation and presentation callbacks, and installs the delegate from `package:silent/localizations.dart`.

The member owns the BWK account and its sessions, foreground scan and listener recovery, and the setup, wallet and settings screens. It resolves opaque secret handles through `Secrets` and uses the existing dedicated keychain capability; the extraction does not migrate account files or keychain entries.
