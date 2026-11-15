import 'dart:io';

import '../../secrets/tool/api_docs.dart'
    show generateApiTrees, updateApiReadme;
import 'native_write_gate.dart' show dartSdkPath;

/// Regenerates the README's call trees from `lib/sync.dart`'s exports, with
/// the generator `secrets` uses.
Future<void> main(List<String> arguments) async {
  if (arguments.any((argument) => argument != '--check')) {
    stderr.writeln(
      'Usage: fvm dart packages/sync/tool/api_docs.dart [--check]',
    );
    exitCode = 64;
    return;
  }
  final package = File.fromUri(Platform.script).parent.parent;
  final check = arguments.contains('--check');
  final trees = await generateApiTrees(
    libraryPath: '${package.path}/lib/sync.dart',
    sdkPath: dartSdkPath(package.path),
    roots: const ['Sync', 'Wallet', 'BackgroundSync', 'BitcoinPolicyCodec'],
    failure: 'SyncFailure',
    target: 'sync-api-docs',
    statics: const {'Sync'},
  );
  final current = updateApiReadme(
    File('${package.path}/README.md'),
    trees,
    check: check,
    marker: 'sync-api',
  );
  if (check && !current) {
    stderr.writeln('Public API trees are stale. Run make sync-api-docs.');
    exitCode = 1;
    return;
  }
  stdout.writeln(
    current ? 'Public API trees are current.' : 'Updated public API trees.',
  );
}
