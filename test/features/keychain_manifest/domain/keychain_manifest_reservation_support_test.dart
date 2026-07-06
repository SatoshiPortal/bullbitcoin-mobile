import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_reservation_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const registry = Bip85RegistryFacade();

  test('every wallet-seed reservation is explicitly classified for v1', () {
    // AD-4 exhaustiveness: adding a Bip85WalletSeedReservation without an
    // explicit backup/recovery classification must fail the build, forcing a
    // human decision (KC-3) instead of silently dropping the product from
    // backups or recovery.
    for (final reservation in registry.reservations) {
      if (reservation is! Bip85WalletSeedReservation) continue;
      expect(
        KeychainManifestReservationSupport.classificationFor(reservation),
        isNotNull,
        reason:
            'Wallet-seed reservation "${reservation.id}" is unclassified. Add '
            'it to KeychainManifestReservationSupport with an explicit '
            'exportableV1 / recoverableV1 / reactivationOnRecovery decision '
            '(a human backup + recovery call, AD-4).',
      );
    }
  });

  test('classification implements the split export vs recovery gates', () {
    final btcpay = registry.reservationById('btcpay_wallet_seed')!;
    final ln = registry.reservationById('lightning_address_wallet_seed')!;
    final page = registry.reservationById('payment_page_wallet_seed')!;
    final pos = registry.reservationById('pos_wallet_seed')!;

    // Exportable: all four Get Paid seeds go into the backup (R2-KC3, [B]).
    expect(KeychainManifestReservationSupport.supportsV1Export(btcpay), true);
    expect(KeychainManifestReservationSupport.supportsV1Export(ln), true);
    expect(KeychainManifestReservationSupport.supportsV1Export(page), true);
    expect(KeychainManifestReservationSupport.supportsV1Export(pos), true);

    // Recoverable at this stack level: BTCPay, Lightning Address, Payment Page,
    // and POS.
    expect(KeychainManifestReservationSupport.supportsV1Recovery(btcpay), true);
    expect(KeychainManifestReservationSupport.supportsV1Recovery(ln), true);
    expect(KeychainManifestReservationSupport.supportsV1Recovery(page), true);
    expect(KeychainManifestReservationSupport.supportsV1Recovery(pos), true);

    // The reactivation-on-recovery intent is recorded for the bullnym-backed
    // products: LN, Payment Page and POS carry the DG-3 auto-heal intent.
    expect(
      KeychainManifestReservationSupport.classificationFor(
        ln,
      )!.reactivationOnRecovery,
      KeychainManifestReactivationOnRecovery.autoHealOnRecoveryPr23,
    );
    expect(
      KeychainManifestReservationSupport.classificationFor(
        page,
      )!.reactivationOnRecovery,
      KeychainManifestReactivationOnRecovery.autoHealOnRecoveryPr23,
    );
    expect(
      KeychainManifestReservationSupport.classificationFor(
        pos,
      )!.reactivationOnRecovery,
      KeychainManifestReactivationOnRecovery.autoHealOnRecoveryPr23,
    );
    expect(
      KeychainManifestReservationSupport.classificationFor(
        btcpay,
      )!.reactivationOnRecovery,
      KeychainManifestReactivationOnRecovery.none,
    );
  });
}
