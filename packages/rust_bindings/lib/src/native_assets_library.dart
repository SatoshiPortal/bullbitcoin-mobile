import 'dart:ffi' as ffi;

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;

ExternalLibrary nativeAssetsLibrary() => _NativeAssetLibrary();

// FRB 2.13's generated wire reads these two fields from ExternalLibrary.
class _NativeAssetLibrary implements ExternalLibrary {
  @override
  final ffi.DynamicLibrary ffiDynamicLibrary = ffi.DynamicLibrary.codeAsset(
    'package:bull_sdk/src/rust/frb_generated.io.dart',
  );

  @override
  final String debugInfo = 'Native Assets: bull_sdk';
}
