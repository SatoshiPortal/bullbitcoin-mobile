import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

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
