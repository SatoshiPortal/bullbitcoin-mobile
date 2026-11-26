import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

/// Files that change the library without touching a `.rs` source: Cargo only
/// reports the sources it compiled, so a manifest, lock or toolchain change
/// alone would otherwise keep the previously built library.
const _manifests = [
  'rust/Cargo.toml',
  'rust/Cargo.lock',
  'rust/rust-toolchain.toml',
];

void main(List<String> args) async {
  await build(args, (input, output) async {
    await const FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'rust',
      extraCargoBuildArgs: ['--locked'],
    ).run(input: input, output: output);
    output.dependencies.addAll(_manifests.map(input.packageRoot.resolve));
  });
}
