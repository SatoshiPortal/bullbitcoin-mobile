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
  'lib/features/recoverbull/router.dart -> locator.dart',
  'lib/features/recoverbull/flow.dart -> locator.dart',
  'lib/features/import_mnemonic/router.dart -> locator.dart',
  'lib/features/mempool_settings/router.dart -> locator.dart',
  'lib/features/recoverbull_google_drive/router.dart -> locator.dart',
  'lib/features/replace_by_fee/router.dart -> locator.dart',
  'lib/features/status_check/router.dart -> locator.dart',
  'lib/features/fund_exchange/fund_exchange_router.dart -> locator.dart',
  'lib/features/app_unlock/ui/pin_code_unlock_screen.dart -> locator.dart',
  'lib/features/electrum_settings/frameworks/ui/routing/electrum_settings_router.dart -> locator.dart',
  'lib/features/dca/ui/dca_router.dart -> locator.dart',
  'lib/features/pay/ui/pay_router.dart -> locator.dart',
  'lib/features/transactions/ui/transactions_router.dart -> locator.dart',
  'lib/features/send/ui/send_router.dart -> locator.dart',
  'lib/features/backup_settings/ui/screens/backup_settings_screen.dart -> locator.dart',
  'lib/features/app_startup/ui/app_startup_widget.dart -> router.dart',
  'lib/features/labels/ui/page.dart -> locator.dart',
  'lib/features/labels/ui/labels_widget.dart -> locator.dart',
  'lib/features/recipients/frameworks/ui/screens/recipients_screen.dart -> locator.dart',
  'lib/features/recipients/ui/screens/sepa_virtual_payee_activation_screen.dart -> locator.dart',
  'lib/features/recipients/ui/screens/virtual_iban_onboarding_screen.dart -> locator.dart',
  'lib/features/recipients/ui/screens/recipient_selection_screen_v2.dart -> locator.dart',
  'lib/features/recipients/ui/screens/virtual_iban_funding_screen.dart -> locator.dart',
  'lib/features/autobuy/ui/autobuy_router.dart -> locator.dart',
  'lib/features/limit_orders/ui/limit_orders_router.dart -> locator.dart',
  'lib/features/sp/ui/sp_router.dart -> locator.dart',
  'lib/features/pin_code/ui/pin_code_setting_flow.dart -> locator.dart',
  'lib/features/buy/ui/buy_router.dart -> locator.dart',
  'lib/features/psbt_flow/show_animated_qr/show_animated_qr_widget.dart -> locator.dart',
  'lib/features/autoswap/ui/screens/autoswap_settings_screen.dart -> locator.dart',
  'lib/features/autoswap/ui/widgets/autoswap_settings.dart -> locator.dart',
  'lib/features/bitbox/presentation/cubit/bitbox_operation_cubit.dart -> locator.dart',
  'lib/features/bitbox/ui/screens/bitbox_action_screen.dart -> locator.dart',
  'lib/features/test_wallet_backup/ui/test_wallet_backup_router.dart -> locator.dart',
  'lib/features/onboarding/ui/onboarding_router.dart -> locator.dart',
  'lib/features/onboarding/ui/screens/onboarding_splash.dart -> locator.dart',
  'lib/features/sell/ui/sell_router.dart -> locator.dart',
  'lib/features/wallet/ui/screens/wallet_detail_screen.dart -> locator.dart',
  'lib/features/wallet/ui/widgets/home_errors.dart -> locator.dart',
  'lib/features/settings/ui/settings_router.dart -> locator.dart',
  'lib/features/settings/ui/widgets/background_preferences.dart -> locator.dart',
  'lib/features/settings/ui/widgets/settings_failure_listener.dart -> router.dart',
  'lib/features/settings/ui/screens/exchange/transactions_screen.dart -> locator.dart',
  'lib/features/swap/ui/swap_router.dart -> locator.dart',
  'lib/features/recoverbull/ui/pages/settings_page.dart -> locator.dart',
  'lib/features/recoverbull/ui/pages/server_confirmation_page.dart -> locator.dart',
  'lib/features/ledger/ui/screens/ledger_action_screen.dart -> locator.dart',
  'lib/features/broadcast_signed_tx/presentation/pages/broadcast_signed_tx_page.dart -> locator.dart',
  'lib/features/tor_settings/public/tor_settings_scope.dart -> locator.dart',
  'lib/features/exchange/ui/exchange_scope.dart -> locator.dart',
  'lib/features/exchange/ui/screens/exchange_home_screen.dart -> locator.dart',
  'lib/features/exchange/ui/screens/exchange_auth_screen.dart -> locator.dart',
  'lib/features/exchange/ui/screens/exchange_kyc_screen.dart -> locator.dart',
  'lib/features/default_wallets/ui/default_wallets_router.dart -> locator.dart',
  'lib/features/exchange_settings/ui/exchange_settings_router.dart -> locator.dart',
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
