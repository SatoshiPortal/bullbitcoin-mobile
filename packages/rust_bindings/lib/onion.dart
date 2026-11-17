/// Re-exports the embedded Tor client that the SDK ships, so consumers depend
/// on a single, SDK-pinned `onion` version instead of pinning it themselves.
///
/// Import with a prefix: `import 'package:bull_sdk/onion.dart' as onion;`
///
/// Unlike lwk and boltz, `onion` is **not** compiled into
/// `librust_lib_bull_sdk.so`: it builds its own, the same way `bdk_dart` does,
/// because it carries a native Android/iOS side of its own (the IPtProxy
/// Snowflake transport). See the comment in the root `Cargo.toml` for the
/// history of that split and what re-merging would require.
///
/// **Not an official Tor Project product.** Tor is a trademark of The Tor
/// Project; all rights reserved — <https://torproject.org>. Not endorsed or
/// sponsored by, or affiliated with, the Tor Project.
library;

export 'package:onion/onion.dart';
