import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter_test/flutter_test.dart';

// Unit tests for the PURE `spRedirect` gate extracted in T4.7. No widget tree,
// no hand-copied redirect closure: the router's real decision is exercised
// directly, so a widget test cannot drift from the shipped gate.
void main() {
  final walletHome = WalletRoute.walletHome.path;
  final spSetup = SpSetupRoute.spSetup.path;

  String? redirect(
    String path, {
    bool isSuperuser = true,
    bool isDevModeEnabled = true,
    bool isSpWalletSetup = true,
  }) => spRedirect(
    path,
    isSuperuser: isSuperuser,
    isDevModeEnabled: isDevModeEnabled,
    isSpWalletSetup: isSpWalletSetup,
    gateClosedRedirectPath: walletHome,
  );

  group('non-SP paths are always allowed', () {
    test('a wallet-home path is never redirected, even with the gate off', () {
      expect(
        redirect(walletHome, isSuperuser: false, isDevModeEnabled: false),
        isNull,
      );
      expect(redirect('/some/other/path'), isNull);
    });
  });

  group('gate off redirects every SP route to wallet home', () {
    // Both false flags, for each SP route and any setup state, must send the
    // user home; the gate is checked before setup so a stale setup can't leak.
    for (final route in SpRoute.values) {
      test('${route.path}: superuser off -> wallet home', () {
        expect(
          redirect(route.path, isSuperuser: false, isSpWalletSetup: true),
          walletHome,
        );
      });

      test('${route.path}: dev mode off -> wallet home', () {
        expect(
          redirect(route.path, isDevModeEnabled: false, isSpWalletSetup: true),
          walletHome,
        );
      });
    }

    test('a nested SP sub-path is gated too', () {
      expect(
        redirect('${SpRoute.spSendConfirm.path}/extra', isSuperuser: false),
        walletHome,
      );
    });
  });

  group('gated on but not set up redirects to SP setup', () {
    for (final route in SpRoute.values) {
      test('${route.path}: not set up -> SP setup', () {
        expect(redirect(route.path, isSpWalletSetup: false), spSetup);
      });
    }
  });

  group('fully gated on and set up is allowed', () {
    for (final route in SpRoute.values) {
      test('${route.path}: superuser + dev mode + setup -> allow', () {
        expect(redirect(route.path), isNull);
      });
    }
  });

  group('spTransactionDetailsRedirect guards the unchecked extra cast', () {
    test('redirects to SP coins when extra is not an SpPayment', () {
      expect(spTransactionDetailsRedirect(null), SpRoute.spCoins.path);
      expect(
        spTransactionDetailsRedirect('not a payment'),
        SpRoute.spCoins.path,
      );
    });

    test('allows the navigation when extra is a valid SpPayment', () {
      final payment = SpPayment(
        txid: 'aabbcc',
        direction: SpPaymentDirection.receive,
        status: SpPaymentStatus.unconfirmed,
        amountSat: BigInt.from(1000),
      );
      expect(spTransactionDetailsRedirect(payment), isNull);
    });
  });
}
