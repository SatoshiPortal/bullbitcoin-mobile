import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Exact legacy feature imports at 982b98e90 (2026-11-06). Remove entries as their
// consumers migrate; never extend this list to permit a new shell dependency.
const _legacyImports = {
  'lib/features/bip85_entropy/router.dart -> locator.dart',
  'lib/features/broadcast_signed_tx/router.dart -> locator.dart',
  'lib/features/import_mnemonic/router.dart -> locator.dart',
  'lib/features/replace_by_fee/router.dart -> locator.dart',
  'lib/features/fund_exchange/fund_exchange_router.dart -> locator.dart',
  'lib/features/dca/ui/dca_router.dart -> locator.dart',
  'lib/features/pay/ui/pay_router.dart -> locator.dart',
  'lib/features/transactions/ui/transactions_router.dart -> locator.dart',
  'lib/features/send/ui/send_router.dart -> locator.dart',
  'lib/features/backup_settings/ui/screens/backup_settings_screen.dart -> locator.dart',
  'lib/features/app_startup/ui/app_startup_widget.dart -> router.dart',
  'lib/features/recipients/ui/screens/recipients_screen.dart -> locator.dart',
  'lib/features/recipients/ui/screens/sepa_virtual_payee_activation_screen.dart -> locator.dart',
  'lib/features/recipients/ui/screens/virtual_iban_onboarding_screen.dart -> locator.dart',
  'lib/features/recipients/ui/screens/virtual_iban_funding_screen.dart -> locator.dart',
  'lib/features/autobuy/ui/autobuy_router.dart -> locator.dart',
  'lib/features/limit_orders/ui/limit_orders_router.dart -> locator.dart',
  'lib/features/sp/ui/sp_router.dart -> locator.dart',
  'lib/features/buy/ui/buy_router.dart -> locator.dart',
  'lib/features/autoswap/ui/screens/autoswap_settings_screen.dart -> locator.dart',
  'lib/features/autoswap/ui/widgets/autoswap_settings.dart -> locator.dart',
  'lib/features/test_wallet_backup/ui/test_wallet_backup_router.dart -> locator.dart',
  'lib/features/onboarding/ui/onboarding_router.dart -> locator.dart',
  'lib/features/sell/ui/sell_router.dart -> locator.dart',
  'lib/features/wallet/ui/screens/wallet_detail_screen.dart -> locator.dart',
  'lib/features/settings/ui/settings_router.dart -> locator.dart',
  'lib/features/settings/ui/widgets/settings_failure_listener.dart -> router.dart',
  'lib/features/swap/ui/swap_router.dart -> locator.dart',
  'lib/features/broadcast_signed_tx/presentation/pages/broadcast_signed_tx_page.dart -> locator.dart',
  'lib/features/exchange/ui/exchange_scope.dart -> locator.dart',
  'lib/features/exchange/ui/screens/exchange_home_screen.dart -> locator.dart',
  'lib/features/exchange/ui/screens/exchange_auth_screen.dart -> locator.dart',
  'lib/features/exchange/ui/screens/exchange_kyc_screen.dart -> locator.dart',
  'lib/features/default_wallets/ui/default_wallets_router.dart -> locator.dart',
  'lib/features/receive/ui/receive_router.dart -> locator.dart',
  'lib/features/receive/ui/receive_router.dart -> router.dart',
  'lib/features/coins/ui/coins_router.dart -> locator.dart',
  'lib/features/withdraw/ui/withdraw_router.dart -> locator.dart',
  'lib/features/exchange_support_chat/ui/screens/exchange_support_chat_screen.dart -> locator.dart',
  'lib/features/consolidation/ui/consolidation_router.dart -> locator.dart',
  'lib/features/consolidation/ui/widgets/consolidation_banner.dart -> locator.dart',
  'lib/features/import_watch_only_wallet/presentation/import_watch_only_screen.dart -> locator.dart',
};

void main() {
  test('the shell uses the wallet facade for service status', () {
    final shell = parseString(
      content: File('lib/locator.dart').readAsStringSync(),
    ).unit;
    final facade = parseString(
      content: File('lib/features/wallet/public/wallet_facade.dart')
          .readAsStringSync(),
    ).unit;

    expect(
      shell.directives
          .whereType<ImportDirective>()
          .map((directive) => directive.uri.stringValue)
          .whereType<String>()
          .where(
            (uri) => const {
              'get_default_wallet_network_usecase.dart',
              'is_tor_required_usecase.dart',
              'wallet_repository.dart',
            }.contains(p.basename(uri)),
          ),
      isEmpty,
    );
    expect(
      facade.directives
          .whereType<ExportDirective>()
          .map((directive) => directive.uri.stringValue)
          .whereType<String>()
          .where((uri) => uri.contains('/domain/usecases/')),
      isEmpty,
    );
  });

  test('features and packages depend on owners, never on the shell', () {
    final root = Directory.current.path;
    final violations = <String>[];
    final legacy = <String>{};
    for (final directory in ['lib/features', 'features', 'packages']) {
      for (final file in Directory(
        directory,
      ).listSync(recursive: true).whereType<File>()) {
        final path = p.relative(file.path, from: root);
        if (!path.endsWith('.dart') ||
            path.split(p.separator).any((part) => part.startsWith('.'))) {
          continue;
        }
        // Only production libraries; test/tool imports have separate contracts.
        if (!path.startsWith('lib/features/') &&
            !RegExp(r'^(features|packages)/[^/]+/lib/').hasMatch(path)) {
          continue;
        }
        final unit = parseString(content: file.readAsStringSync()).unit;
        for (final directive in unit.directives) {
          final uris = <String?>[
            if (directive is UriBasedDirective) directive.uri.stringValue,
            if (directive is ImportDirective)
              ...directive.configurations.map((c) => c.uri.stringValue),
            if (directive is ExportDirective)
              ...directive.configurations.map((c) => c.uri.stringValue),
            if (directive is PartOfDirective) directive.uri?.stringValue,
          ];
          for (final uri in uris.whereType<String>()) {
            final String target;
            if (uri.startsWith('package:bb_mobile/')) {
              if (path.startsWith('packages/') ||
                  path.startsWith('features/')) {
                violations.add('$path -> $uri (package imports app)');
                continue;
              }
              target = p.join(
                root,
                'lib',
                uri.substring('package:bb_mobile/'.length),
              );
            } else if (Uri.parse(uri).scheme == 'file') {
              target = Uri.parse(uri).toFilePath();
            } else if (Uri.parse(uri).hasScheme) {
              continue;
            } else {
              target = p.normalize(p.join(root, p.dirname(path), uri));
            }
            if (!path.startsWith('lib/') &&
                p.isWithin(p.join(root, 'lib'), target)) {
              violations.add('$path -> $uri (package imports app)');
              continue;
            }
            if (p.dirname(target) != p.join(root, 'lib')) continue;
            final edge = '$path -> ${p.basename(target)}';
            if (_legacyImports.contains(edge)) {
              legacy.add(edge);
            } else {
              violations.add(edge);
            }
          }
        }
      }
    }
    expect(violations, isEmpty);
    expect(legacy, _legacyImports, reason: 'Remove obsolete debt entries too.');
  });
}
