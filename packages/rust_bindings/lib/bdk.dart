/// Re-exports the Bitcoin Development Kit (BDK) FFI bindings that the SDK is
/// built on, so consumers depend on a single, SDK-pinned bdk_dart version
/// instead of pinning bdk_dart themselves.
///
/// Import with a prefix: `import 'package:bull_sdk/bdk.dart' as bdk;`
library;

export 'package:bdk_dart/bdk.dart';
