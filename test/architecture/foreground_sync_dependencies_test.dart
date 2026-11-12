import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Source-edge baseline generated once from 4c3385e6c (2026-11-07).
// These 174 edges include legacy violations, not architectural permission.
// Remove retired edges; review any addition instead of regenerating this list.
// In particular, sp/swap -> wallet predates foreground sync: repository
// compatibility exports and swap's wallet navigation remain out of scope.
const _allowedTargets = <String, String>{
  'address_view': 'settings wallet',
  'all_seed_view': 'app_unlock wallet',
  'announcements': 'settings swap',
  'app_startup': 'app_unlock logs onboarding pin_code wallet',
  'app_unlock': 'pin_code wallet',
  'autobuy': 'default_wallets',
  'autoswap': 'labels swap wallet',
  'backup_settings': 'recoverbull settings test_wallet_backup wallet',
  'bip85_entropy': 'wallet',
  'bitbox': 'import_watch_only_wallet',
  'bitcoin_price': 'settings',
  'broadcast_signed_tx': 'send settings wallet',
  'buy': 'exchange fund_exchange labels settings transactions wallet',
  'coins': 'bitcoin_price labels settings wallet',
  'consolidation': 'wallet',
  'dca': 'exchange fund_exchange wallet',
  'electrum_settings': 'tor_settings',
  'exchange':
      'autobuy bitcoin_price dca exchange_support_chat fund_exchange transactions withdraw',
  'exchange_settings': 'exchange',
  'fund_exchange': 'exchange recipients',
  'import_coldcard': 'import_watch_only_wallet',
  'import_mnemonic': 'wallet',
  'import_qr_device': 'import_watch_only_wallet',
  'import_wallet':
      'bitbox import_coldcard import_mnemonic import_qr_device import_watch_only_wallet ledger',
  'import_watch_only_wallet': 'wallet',
  'ledger': 'import_watch_only_wallet',
  'limit_orders': 'default_wallets exchange fund_exchange',
  'onboarding':
      'electrum_settings mempool_settings recoverbull settings tor_settings wallet',
  'pay': 'bitcoin_price exchange recipients send transactions wallet',
  'pin_code': 'app_unlock settings test_wallet_backup wallet',
  'psbt_flow': 'broadcast_signed_tx',
  'receive': 'bitbox labels ledger settings swap transactions wallet',
  'recoverbull': 'recoverbull_google_drive tor_settings wallet',
  'recoverbull_google_drive': 'recoverbull',
  'replace_by_fee': 'wallet',
  'sell': 'bitcoin_price exchange labels recipients send transactions wallet',
  'send':
      'bitbox consolidation labels ledger psbt_flow sp swap transactions wallet',
  'settings':
      'address_view all_seed_view app_unlock autoswap backup_settings bip85_entropy bitcoin_price broadcast_signed_tx default_wallets electrum_settings exchange exchange_settings import_wallet labels logs mempool_settings pay pin_code recoverbull sp status_check test_wallet_backup tor_settings transactions wallet',
  'sp': 'wallet',
  'status_check': 'wallet',
  'support': 'exchange_support_chat',
  'swap': 'consolidation labels send transactions wallet',
  'test_wallet_backup': 'onboarding wallet',
  'transactions': 'buy exchange labels pay replace_by_fee settings swap wallet',
  'wallet':
      'announcements backup_settings bitcoin_price consolidation electrum_settings exchange import_watch_only_wallet labels onboarding receive send settings sp swap tor_settings transactions',
  'withdraw': 'exchange recipients transactions',
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
  test('resolves owners through relative, public and conditional exports', () {
    final edges = _edges(
      {
        'lib/features/sp/renamed.dart':
            "import '../../core/barrel.dart'; import 'local.dart';",
        'lib/features/sp/local.dart': '',
        'lib/core/barrel.dart':
            "export 'barrel.dart'; export '../features/wallet/public/api.dart';",
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
        final lib = Directory(
          root.toFilePath(),
        ).uri.resolve(package['packageUri'] as String? ?? 'lib/').toFilePath();
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
