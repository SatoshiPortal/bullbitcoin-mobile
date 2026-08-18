import 'package:bb_mobile/router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('classifies every configured GoRoute destination', () {
    final destinations = _collectDestinations(
      AppRouter.router.configuration.routes,
    );
    final paths = destinations.map((route) => route.path).toList();
    final names = destinations
        .map((route) => route.name)
        .whereType<String>()
        .toList();

    expect(destinations, hasLength(144));
    expect(paths.toSet(), hasLength(paths.length), reason: 'Duplicate paths');
    expect(names.toSet(), hasLength(names.length), reason: 'Duplicate names');
    expect(
      paths.toSet(),
      _routeCoverage.keys.toSet(),
      reason:
          'Unregistered: ${paths.toSet().difference(_routeCoverage.keys.toSet())}; '
          'orphaned: ${_routeCoverage.keys.toSet().difference(paths.toSet())}',
    );
  });
}

enum RouteCoverageCategory {
  safe,
  fixture,
  secret,
  hardware,
  networkAccount,
  destructiveFinancial,
}

// This registry measures destination coverage, not business-state coverage.
// Restricted destinations remain registered so exclusions stay explicit and a
// newly added route cannot silently bypass the UI coverage inventory.
const _routeCoverage = <String, RouteCoverageCategory>{
  '/wallet': RouteCoverageCategory.fixture,
  '/exchange': RouteCoverageCategory.networkAccount,
  '/exchange/kyc': RouteCoverageCategory.networkAccount,
  '/exchange/landing': RouteCoverageCategory.networkAccount,
  '/exchange/login-support': RouteCoverageCategory.networkAccount,
  '/exchange/support-chat': RouteCoverageCategory.networkAccount,
  '/exchange/auth': RouteCoverageCategory.networkAccount,
  '/onboarding': RouteCoverageCategory.secret,
  '/onboarding/splash': RouteCoverageCategory.secret,
  '/onboarding/recover-from-physical': RouteCoverageCategory.secret,
  '/onboarding/recover-options': RouteCoverageCategory.secret,
  '/app-unlock': RouteCoverageCategory.secret,
  '/wallet/:walletId': RouteCoverageCategory.fixture,
  '/consolidate/:walletId': RouteCoverageCategory.destructiveFinancial,
  '/settings': RouteCoverageCategory.networkAccount,
  '/settings/exchange-account': RouteCoverageCategory.networkAccount,
  '/settings/exchange-settings': RouteCoverageCategory.networkAccount,
  '/settings/exchange-account-info': RouteCoverageCategory.networkAccount,
  '/settings/exchange-security': RouteCoverageCategory.networkAccount,
  '/settings/exchange-bitcoin-wallets': RouteCoverageCategory.networkAccount,
  '/settings/exchange-app-settings': RouteCoverageCategory.networkAccount,
  '/settings/exchange-file-upload': RouteCoverageCategory.networkAccount,
  '/settings/exchange-statistics': RouteCoverageCategory.networkAccount,
  '/settings/exchange-transactions': RouteCoverageCategory.networkAccount,
  '/settings/exchange-legacy-transactions':
      RouteCoverageCategory.networkAccount,
  '/settings/exchange-referrals': RouteCoverageCategory.networkAccount,
  '/settings/exchange-logout': RouteCoverageCategory.destructiveFinancial,
  '/settings/bitcoin-settings': RouteCoverageCategory.fixture,
  '/settings/payjoin-settings': RouteCoverageCategory.networkAccount,
  '/settings/payjoin-advanced-settings': RouteCoverageCategory.networkAccount,
  '/settings/autoswap-settings': RouteCoverageCategory.networkAccount,
  '/settings/app-settings': RouteCoverageCategory.safe,
  '/settings/app-settings/tor-settings': RouteCoverageCategory.networkAccount,
  '/settings/theme': RouteCoverageCategory.safe,
  '/settings/pin-code': RouteCoverageCategory.secret,
  '/settings/backup-settings': RouteCoverageCategory.secret,
  '/settings/backup-settings/backup-options': RouteCoverageCategory.secret,
  '/settings/backup-settings/test-physical-backup-flow':
      RouteCoverageCategory.secret,
  '/settings/wallet-details': RouteCoverageCategory.fixture,
  '/settings/wallet-details/:walletId/options': RouteCoverageCategory.fixture,
  '/settings/wallet-details/:walletId': RouteCoverageCategory.fixture,
  '/settings/wallet-details/:walletId/addresses': RouteCoverageCategory.fixture,
  '/settings/logs': RouteCoverageCategory.safe,
  '/settings/seed-viewer': RouteCoverageCategory.secret,
  '/settings/currency': RouteCoverageCategory.safe,
  '/settings/btc-map': RouteCoverageCategory.networkAccount,
  '/transactions': RouteCoverageCategory.fixture,
  '/transactions/export': RouteCoverageCategory.fixture,
  '/transaction/:txId': RouteCoverageCategory.fixture,
  '/transaction/payjoin/tx/:txId': RouteCoverageCategory.fixture,
  '/transaction/swap/:swapId': RouteCoverageCategory.fixture,
  '/transaction/payjoin/:payjoinId': RouteCoverageCategory.fixture,
  '/transaction/order-swap/:localId': RouteCoverageCategory.fixture,
  '/transaction/order/:orderId': RouteCoverageCategory.networkAccount,
  '/receive/bitcoin': RouteCoverageCategory.fixture,
  '/receive/bitcoin/amount': RouteCoverageCategory.fixture,
  '/receive/bitcoin/payjoin': RouteCoverageCategory.networkAccount,
  '/receive/lightning': RouteCoverageCategory.networkAccount,
  '/receive/lightning/qr': RouteCoverageCategory.networkAccount,
  '/receive/lightning/qr/amount': RouteCoverageCategory.networkAccount,
  '/receive/lightning/qr/in-progress': RouteCoverageCategory.networkAccount,
  '/receive/lightning/qr/received': RouteCoverageCategory.networkAccount,
  '/receive/liquid': RouteCoverageCategory.networkAccount,
  '/receive/liquid/amount': RouteCoverageCategory.networkAccount,
  '/send': RouteCoverageCategory.destructiveFinancial,
  '/send/request-identifier': RouteCoverageCategory.fixture,
  '/coins': RouteCoverageCategory.fixture,
  '/swap': RouteCoverageCategory.destructiveFinancial,
  '/swap/confirm': RouteCoverageCategory.destructiveFinancial,
  '/swap/in-progress': RouteCoverageCategory.destructiveFinancial,
  '/swap/scan-qr': RouteCoverageCategory.hardware,
  '/buy': RouteCoverageCategory.destructiveFinancial,
  '/buy/confirmation': RouteCoverageCategory.destructiveFinancial,
  '/buy/confirmation/success': RouteCoverageCategory.destructiveFinancial,
  '/buy/:orderId/accelerate': RouteCoverageCategory.destructiveFinancial,
  '/buy/:orderId/accelerate/success':
      RouteCoverageCategory.destructiveFinancial,
  '/fund-exchange': RouteCoverageCategory.networkAccount,
  '/fund-exchange/cop-bank-transfer-input':
      RouteCoverageCategory.networkAccount,
  '/fund-exchange-email-e-transfer': RouteCoverageCategory.networkAccount,
  '/fund-exchange-bank-transfer-wire': RouteCoverageCategory.networkAccount,
  '/fund-exchange-online-bill-payment': RouteCoverageCategory.networkAccount,
  '/fund-exchange-canada-post': RouteCoverageCategory.networkAccount,
  '/fund-exchange-instant-sepa': RouteCoverageCategory.networkAccount,
  '/fund-exchange-regular-sepa': RouteCoverageCategory.networkAccount,
  '/fund-exchange-spei-transfer': RouteCoverageCategory.networkAccount,
  '/fund-exchange-sinpe': RouteCoverageCategory.networkAccount,
  '/fund-exchange-cr-iban-crc': RouteCoverageCategory.networkAccount,
  '/fund-exchange-cr-iban-usd': RouteCoverageCategory.networkAccount,
  '/fund-exchange-ars-bank-transfer': RouteCoverageCategory.networkAccount,
  '/fund-exchange-cop-bank-transfer': RouteCoverageCategory.networkAccount,
  '/sell': RouteCoverageCategory.destructiveFinancial,
  '/sell/wallet-selection': RouteCoverageCategory.destructiveFinancial,
  '/sell/send-payment': RouteCoverageCategory.destructiveFinancial,
  '/sell/external-wallet-network-selection':
      RouteCoverageCategory.destructiveFinancial,
  '/sell/external-wallet-receive-payment':
      RouteCoverageCategory.destructiveFinancial,
  '/sell/success': RouteCoverageCategory.destructiveFinancial,
  '/withdraw': RouteCoverageCategory.destructiveFinancial,
  '/withdraw/recipients': RouteCoverageCategory.destructiveFinancial,
  '/withdraw/confirmation': RouteCoverageCategory.destructiveFinancial,
  '/withdraw/success': RouteCoverageCategory.destructiveFinancial,
  '/pay': RouteCoverageCategory.destructiveFinancial,
  '/pay/amount': RouteCoverageCategory.destructiveFinancial,
  '/pay/wallet-selection': RouteCoverageCategory.destructiveFinancial,
  '/pay/external-wallet-network-selection':
      RouteCoverageCategory.destructiveFinancial,
  '/pay/send-payment': RouteCoverageCategory.destructiveFinancial,
  '/pay/receive-payment': RouteCoverageCategory.destructiveFinancial,
  '/pay/in-progress': RouteCoverageCategory.destructiveFinancial,
  '/pay/payment-completed': RouteCoverageCategory.destructiveFinancial,
  '/pay/sinpe-success': RouteCoverageCategory.destructiveFinancial,
  '/import-mnemonic-home': RouteCoverageCategory.secret,
  '/select-script-type': RouteCoverageCategory.secret,
  '/import-watch-only': RouteCoverageCategory.fixture,
  '/import-watch-only-scanner': RouteCoverageCategory.hardware,
  '/broadcast-signed-tx': RouteCoverageCategory.destructiveFinancial,
  '/broadcast-signed-tx/scan-qr': RouteCoverageCategory.hardware,
  '/broadcast-signed-tx/scan-nfc': RouteCoverageCategory.hardware,
  '/show-psbt': RouteCoverageCategory.hardware,
  '/import-wallet-home': RouteCoverageCategory.secret,
  '/import-coldcard-q': RouteCoverageCategory.hardware,
  '/import-coldcard-mk4': RouteCoverageCategory.hardware,
  '/ledger-import': RouteCoverageCategory.hardware,
  '/ledger-sign-transaction': RouteCoverageCategory.hardware,
  '/ledger-verify-address': RouteCoverageCategory.hardware,
  '/bitbox-import': RouteCoverageCategory.hardware,
  '/bitbox-sign-transaction': RouteCoverageCategory.hardware,
  '/bitbox-verify-address': RouteCoverageCategory.hardware,
  '/dca': RouteCoverageCategory.destructiveFinancial,
  '/dca/wallet-selection': RouteCoverageCategory.destructiveFinancial,
  '/dca/confirmation': RouteCoverageCategory.destructiveFinancial,
  '/dca/success': RouteCoverageCategory.destructiveFinancial,
  '/replace-by-fee-flow': RouteCoverageCategory.destructiveFinancial,
  '/bip85-home': RouteCoverageCategory.secret,
  '/electrum-settings': RouteCoverageCategory.networkAccount,
  '/mempool-settings': RouteCoverageCategory.networkAccount,
  '/import-jade': RouteCoverageCategory.hardware,
  '/import-krux': RouteCoverageCategory.hardware,
  '/import-keystone': RouteCoverageCategory.hardware,
  '/import-passport': RouteCoverageCategory.hardware,
  '/import-seedsigner': RouteCoverageCategory.hardware,
  '/import-specter': RouteCoverageCategory.hardware,
  '/recoverbull-flows': RouteCoverageCategory.secret,
  '/recoverbull/drive/list': RouteCoverageCategory.secret,
  '/labels': RouteCoverageCategory.fixture,
  '/service-status': RouteCoverageCategory.networkAccount,
};

List<({String path, String? name})> _collectDestinations(
  List<RouteBase> routes, [
  String parentPath = '',
]) {
  final destinations = <({String path, String? name})>[];

  for (final route in routes) {
    final routePath = switch (route) {
      GoRoute(:final path) => _joinPaths(parentPath, path),
      _ => parentPath,
    };

    if (route case GoRoute(:final name)) {
      destinations.add((path: routePath, name: name));
    }
    destinations.addAll(_collectDestinations(route.routes, routePath));
  }

  return destinations;
}

String _joinPaths(String parent, String child) {
  final normalizedChild = child.startsWith('/') ? child.substring(1) : child;
  if (parent.isEmpty || parent == '/') return '/$normalizedChild';
  final normalizedParent = parent.endsWith('/')
      ? parent.substring(0, parent.length - 1)
      : parent;
  return '$normalizedParent/$normalizedChild';
}
