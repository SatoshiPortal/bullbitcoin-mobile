import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// A workspace member is reached only through the libraries directly under its
// lib/: the analyzer's implementation_imports lint covers lib/src only, so an
// import of any other nested file (lib/data/..., lib/domain/...) would pass
// unnoticed. No member imports the app.

/// Pre-existing imports of a non-exported file, to fix in their own change.
const _knownExceptions = <String, Set<String>>{
  // The renewal client tests assemble the closed client around the real
  // inventory fixture; the client is deliberately not a public library.
  'test/features/ark/ark_renewal_client_test.dart': {
    'package:bull_ark/src/data/ark_renewal_client.dart',
    'package:bull_ark/src/domain/ark_failure.dart',
    'package:bull_ark/src/domain/repositories/ark_account_registry_repository.dart',
  },
  // Runs the real background sync of a locked view against the fixture.
  'test/features/sync/public_sync_locked_view_test.dart': {
    'package:background_tasks/src/data/background_wallet_sync_impl.dart',
  },
  // ExternalTorPort is not exported by bull_tor's public libraries.
  'test/core_test/recoverbull/ensure_recoverbull_tor_session_usecase_test.dart':
      {'package:bull_tor/src/domain/ports/external_tor_port.dart'},
  // The default-passphrase device test assembles the RecoverBull vault flow from its internals.
  'integration_test/device/default_passphrase_device_test.dart': {
    'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart',
    'package:bull_recoverbull/src/data/secrets_vault_repository.dart',
    'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart',
    'package:bull_recoverbull/src/domain/usecases/complete_vault_usecase.dart',
    'package:bull_recoverbull/src/domain/usecases/delete_drive_vault_usecase.dart',
    'package:bull_recoverbull/src/domain/usecases/export_drive_vault_usecase.dart',
    'package:bull_recoverbull/src/domain/usecases/list_drive_vaults_usecase.dart',
    'package:bull_recoverbull/src/domain/usecases/manage_backup_settings_usecase.dart',
    'package:bull_recoverbull/src/domain/usecases/pick_vault_usecase.dart',
    'package:bull_recoverbull/src/domain/usecases/read_drive_vault_usecase.dart',
    'package:bull_recoverbull/src/domain/usecases/restore_vault_usecase.dart',
    'package:bull_recoverbull/src/domain/usecases/test_vault_usecase.dart',
    'package:bull_recoverbull/src/presentation/vault_flow_cubit.dart',
    'package:bull_recoverbull/src/presentation/vault_flow_presentation.dart',
    'package:bull_recoverbull/src/ui/pages/password_input_page.dart',
    'package:bull_recoverbull/src/ui/recoverbull_flow_navigator.dart',
  },
};

final _directive = RegExp(r'^\s*(?:import|export)\s+[^;]+;', multiLine: true);
final _packageUri = RegExp(r'''['"]package:([a-z0-9_]+)/([^'"]+)['"]''');

Iterable<RegExpMatch> _packageImports(String source) => _directive
    .allMatches(source)
    .expand((directive) => _packageUri.allMatches(directive.group(0) ?? ''));

Map<String, String> _workspaceMembers() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  final start = lines.indexWhere((line) => line.startsWith('workspace:'));
  final members = <String, String>{};
  for (final line in lines.skip(start + 1)) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    final directory = RegExp(r'^\s+-\s+(\S+)\s*$').firstMatch(line)?.group(1);
    if (directory == null) break;
    final name = RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(File('$directory/pubspec.yaml').readAsStringSync())?.group(1);
    if (name == null) fail('$directory/pubspec.yaml has no name');
    members[name] = directory;
  }
  return members;
}

void main() {
  test('conditional import and export URIs are included', () {
    const source =
        "import 'stub.dart' if (dart.library.io) 'package:bb_mobile/app.dart';\n"
        "export 'package:primitives/primitives.dart' if (dart.library.io) 'package:bb_mobile/init.dart';";
    expect(_packageImports(source).map((match) => match.group(1)), [
      'bb_mobile',
      'primitives',
      'bb_mobile',
    ]);
  });
  test(
    'workspace members are imported only through their public libraries',
    () {
      final members = _workspaceMembers();
      expect(members, isNotEmpty);
      final violations = <String>[];
      final files =
          Process.runSync('git', [
                'ls-files',
                '--cached',
                '--others',
                '--exclude-standard',
                '*.dart',
              ]).stdout
              .toString()
              .split('\n')
              .where((path) => path.isNotEmpty && File(path).existsSync());
      for (final path in files) {
        final owner = members.entries
            .where((member) => path.startsWith('${member.value}/'))
            .map((member) => member.key)
            .firstOrNull;
        for (final match in _packageImports(File(path).readAsStringSync())) {
          final package = match.group(1);
          final libraryPath = match.group(2) ?? '';
          final uri = 'package:$package/$libraryPath';
          final crossesMember =
              members.containsKey(package) &&
              package != owner &&
              libraryPath.contains('/');
          final importsApp = owner != null && package == 'bb_mobile';
          if ((crossesMember || importsApp) &&
              !(_knownExceptions[path]?.contains(uri) ?? false)) {
            violations.add('$path: $uri');
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );
}
