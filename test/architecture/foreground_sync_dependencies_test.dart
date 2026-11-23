import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Source-edge baseline generated once from 4c3385e6c (2026-11-07).
// These edges include legacy violations, not architectural permission.
// Networks owner moves and captured-network consumers: see the per-edge review
// in FEATURES.md (2026-11-07); do not regenerate this baseline blindly.
// Remove retired edges; review any addition instead of regenerating this list.
// Swap still imports the wallet repository and uses wallet navigation.
// Silent receives a fingerprint reader through composition, not a wallet import.
// Ark integration reviewed on 2026-11-19: send and swap use its public facade;
// settings and wallet use its published UI and foreground setup capabilities.
// These four edges are documented in FEATURES.md.
// QR and NFC consumers use the scanning feature's public capabilities; its
// implementation has no dependencies on those consumers (see FEATURES.md).
// Label Editor publishes the existing note, label and import/export UI. Its
// consumers use that surface while data-only consumers depend on the package.
// Wallet reader ownership (2026-11-22): see FEATURES.md for the address,
// coin, receive and history edges that replace the legacy wallet placements.
// Exchange workspace UI consumers use the published routes (see FEATURES.md).
const _allowedTargets = <String, String>{
  'address_view': 'label_editor',
  'all_seed_view': 'access',
  'autoswap': 'address_view swap wallet',
  'backup_settings': 'backups recoverbull settings test_wallet_backup wallet',
  'backups': 'recoverbull',
  'broadcast_signed_tx': 'address_view scanning wallet',
  'bull_exchange': 'bitcoin_price',
  'coins': 'address_view bitcoin_price wallet',
  'consolidation': 'wallet',
  'exchange': 'address_view bull_exchange transactions wallet',
  'import_coldcard': 'scanning signers wallet_import',
  'import_mnemonic': 'mnemonic_entry wallet wallet_import',
  'import_wallet': 'import_coldcard import_mnemonic import_watch_only_wallet settings signers wallet_import',
  'import_watch_only_wallet': 'scanning signers wallet wallet_import',
  'limit_orders': 'address_view bull_exchange exchange wallet',
  'network': 'recoverbull',
  'onboarding':
      'mnemonic_entry network recoverbull settings wallet wallet_import',
  'pay': 'address_view bitcoin_price bull_exchange coins exchange fees transactions wallet',
  'receive':
      'address_view label_editor settings signers swap transactions wallet',
  'replace_by_fee': 'fees wallet',
  'scanning': 'signers',
  'sell': 'address_view bitcoin_price bull_exchange coins exchange fees transactions wallet',
  'send': 'address_view ark coins consolidation fees label_editor signers silent swap transactions wallet',
  'settings': 'access address_view all_seed_view ark autoswap backup_settings backups bip85 bitcoin_price broadcast_signed_tx bull_exchange exchange fees import_wallet label_editor logs network pay quick_actions recoverbull silent swap test_wallet_backup transactions wallet',
  'support': 'bull_exchange',
  'startup': 'access logs mnemonic_entry recoverbull',
  'swap': 'address_view ark coins consolidation fees send transactions wallet',
  'test_wallet_backup':
      'access onboarding physical_backup_verification recoverbull wallet',
  'transactions': 'bitcoin_price label_editor',
  'wallet': 'address_view ark backup_settings backups bitcoin_price coins consolidation import_watch_only_wallet network onboarding quick_actions receive recoverbull scanning send settings signers silent swap transactions',
  'wallet_import': 'signers',
  'wizard': 'bull_exchange settings',
};

String? _owner(String path) {
  final parts = p.split(path);
  if (parts.length > 3 && parts[0] == 'lib' && parts[1] == 'features') {
    return parts[2];
  }
  if (parts.length > 3 && parts[0] == 'features' && parts[2] == 'lib') {
    return parts[1];
  }
  return null;
}

String? _target(String source, String uri, Map<String, String> packages) {
  final parsed = Uri.parse(uri);
  if (parsed.scheme == 'package') {
    final parts = parsed.pathSegments;
    final root = packages[parts.first];
    return root == null
        ? null
        : p.normalize(p.joinAll([root, ...parts.skip(1)]));
  }
  if (parsed.hasScheme) return null;
  return p.normalize(p.join(p.dirname(source), uri));
}

// Parse each file once. Follow exports (including public/conditional barrels),
// not imports of imported libraries: those belong to the imported file's owner.
Map<String, String> _edges(
  Map<String, String> sources,
  Map<String, String> packages,
) {
  final dependencies = <String, List<String>>{};
  final exports = <String, List<String>>{};
  for (final entry in sources.entries) {
    dependencies[entry.key] = [];
    exports[entry.key] = [];
    final unit = parseString(content: entry.value).unit;
    for (final directive in unit.directives) {
      if (directive is! ImportDirective && directive is! ExportDirective) {
        continue;
      }
      final uris = <String?>[
        if (directive is UriBasedDirective) directive.uri.stringValue,
        if (directive is ImportDirective)
          ...directive.configurations.map((c) => c.uri.stringValue),
        if (directive is ExportDirective)
          ...directive.configurations.map((c) => c.uri.stringValue),
      ];
      for (final uri in uris.whereType<String>()) {
        final target = _target(entry.key, uri, packages);
        if (target == null || !sources.containsKey(target)) continue;
        dependencies[entry.key]?.add(target);
        if (directive is ExportDirective) exports[entry.key]?.add(target);
      }
    }
  }
  final edges = <String, String>{};
  for (final entry in dependencies.entries) {
    final owner = _owner(entry.key);
    if (owner == null) continue;
    final pending = entry.value.map((target) => [entry.key, target]).toList();
    final seen = <String>{};
    while (pending.isNotEmpty) {
      final chain = pending.removeLast();
      final target = chain.last;
      if (!seen.add(target)) continue;
      final other = _owner(target);
      if (other != null && other != owner) {
        edges.putIfAbsent('$owner -> $other', () => chain.join(' -> '));
      }
      for (final exported in exports[target] ?? <String>[]) {
        pending.add([...chain, exported]);
      }
    }
  }
  return edges;
}

void main() {
  test('the retired core exchange has no compatibility library', () {
    expect(Directory('lib/core/exchange').existsSync(), isFalse);
    expect(File('lib/core/errors/exchange_errors.dart').existsSync(), isFalse);
  });

  test(
    'preferences are consumed through feature use cases in presentation',
    () {
      final preferenceField = RegExp(r'\bPreferences\s+_\w+\s*;');
      for (final path in [
        'lib/features/send/presentation/bloc/send_cubit.dart',
        'lib/features/settings/presentation/bloc/settings_cubit.dart',
        'lib/features/swap/presentation/transfer_bloc.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          isNot(matches(preferenceField)),
          reason: path,
        );
      }
    },
  );

  test('resolves owners through relative, public and conditional exports', () {
    final edges = _edges(
      {
        'lib/features/sp/renamed.dart':
            "import '../../core/barrel.dart'; import 'local.dart';",
        'lib/features/sp/local.dart': '',
        'lib/core/barrel.dart': "export 'barrel.dart'; export '../features/wallet/public/api.dart';",
        'lib/features/wallet/public/api.dart':
            "export '../data/repository.dart' if (dart.library.io) "
            "'package:bb_mobile/features/swap/anything.dart'; "
            "export 'package:bull_logs/bull_logs.dart';",
        'lib/features/wallet/data/repository.dart': '',
        'lib/features/swap/anything.dart': '',
        'features/logs/lib/bull_logs.dart': '',
      },
      {'bb_mobile': 'lib', 'bull_logs': 'features/logs/lib'},
    );
    expect(
      edges.keys,
      unorderedEquals([
        'sp -> wallet',
        'sp -> swap',
        'sp -> logs',
        'wallet -> swap',
        'wallet -> logs',
      ]),
    );
  });

  test(
    'feature source dependencies cannot grow beyond the reviewed baseline',
    () {
      final configFile = File('.dart_tool/package_config.json');
      final config =
          jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      final packages = <String, String>{};
      for (final package in config['packages'] as List<dynamic>) {
        final root = configFile.absolute.uri.resolve(
          package['rootUri'] as String,
        );
        final lib = Directory(root.toFilePath()).uri
            .resolve(package['packageUri'] as String? ?? 'lib/')
            .toFilePath();
        if (p.isWithin(Directory.current.path, lib)) {
          packages[package['name'] as String] = p.relative(lib);
        }
      }
      final sources = <String, String>{};
      for (final root in packages.values) {
        for (final file in Directory(
          root,
        ).listSync(recursive: true).whereType<File>()) {
          if (file.path.endsWith('.dart')) {
            sources[p.normalize(file.path)] = file.readAsStringSync();
          }
        }
      }
      final edges = _edges(sources, packages);
      final allowed = {
        for (final entry in _allowedTargets.entries)
          for (final target in entry.value.split(' '))
            '${entry.key} -> $target',
      };
      final added = edges.keys.toSet().difference(allowed).toList()..sort();
      expect(
        added,
        isEmpty,
        reason: added.map((edge) => '$edge: ${edges[edge]}').join('\n'),
      );
      expect(
        allowed.difference(edges.keys.toSet()),
        isEmpty,
        reason: 'Remove retired edges from the allowlist.',
      );
    },
  );
}
