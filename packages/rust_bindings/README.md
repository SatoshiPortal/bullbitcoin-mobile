# rust_bindings

Unified Flutter Rust Bridge bindings for Bitcoin and Liquid wallet operations. Flutter 3.50 / Dart 3.14 builds and bundles the Rust library through Native Assets.

```dart
import 'package:rust_bindings/rust_bindings.dart';

await BullSdk.init();
```

The default initializer loads the registered `package:rust_bindings/src/rust/frb_generated.io.dart` code asset. An explicit `externalLibrary` still selects a caller-provided library; `initMock` remains available for tests. Native Assets builds the Rust library; the legacy CargoKit and downloaded Rust-library paths are removed.

After changing the Rust API, run `make rust-bindings-codegen` from the repository root (flutter_rust_bridge_codegen 2.13.0, then `fix_frb_generated.sh`). The post-processing preserves external error/type conversions, checked unsigned integers and Native Assets loading. Commit the generated bridge separately.

Boltz supports concrete Bitcoin and Liquid regtest chains with caller-supplied Boltz and Electrum URLs. For TCP Electrum, pass explicit settings with `tls: false` and `validateDomain: false`. `checkLockupOutspends` requires an explicit `explorerUrl` on regtest, without a public-explorer fallback. Quote URLs use the existing `Fees.newInstance` constructor.

Version 2.0.0 changes the generated `ChainSwap` API and native ABI: constructors take `network` instead of `isTestnet`, and stored objects expose `network`. Regenerate consumers and ship the matching native library together with their Dart bindings. FRB's content hash does not detect every signature change. Synthetic mainnet/testnet fixtures with empty private fields round-trip the legacy `is_testnet` representation through the aggregate bridge; they are not captured historical ce7 output. Production serialization remains compatible with that legacy representation; regtest uses an explicit discriminator that older readers reject. Swap creation also rejects mismatched master-key networks on mainnet and testnet before parsing or IO.

Apple packaging and signing require a full Xcode build on macOS.
