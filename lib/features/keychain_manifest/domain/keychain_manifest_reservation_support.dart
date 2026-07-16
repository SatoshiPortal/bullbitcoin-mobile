import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';

/// Post-recovery handling for product-owned wallet material.
enum KeychainManifestReactivationOnRecovery {
  /// Local materialization is sufficient; nothing to re-activate.
  none,

  /// A Bullnym-backed product whose registration is checked and silently
  /// repaired after recovery. The value name is frozen manifest-era API.
  autoHealOnRecoveryPr23,
}

/// Explicit v1 classification of a reserved wallet seed for the keychain
/// manifest: whether it is exported into the backup, whether it is recovered
/// FROM a backup at this stack level, and its post-recovery reactivation
/// intent.
class KeychainManifestReservationClassification {
  /// Included in the v1 manifest backup (so funded product wallets are never
  /// silently excluded - KC-3).
  final bool exportableV1;

  /// Materialized when restoring from a manifest at this stack level.
  final bool recoverableV1;

  final KeychainManifestReactivationOnRecovery reactivationOnRecovery;

  const KeychainManifestReservationClassification({
    required this.exportableV1,
    required this.recoverableV1,
    required this.reactivationOnRecovery,
  });
}

/// v1 keychain-manifest support classification for reserved wallet seeds.
///
/// Every [Bip85WalletSeedReservation] MUST appear in [_classifications]; the
/// AD-4 exhaustiveness test fails the build otherwise, forcing a human backup /
/// recovery decision on any newly reserved product seed rather than silently
/// dropping it from backups (KC-3) or from recovery.
///
/// BTCPay, Lightning Address, and Payment Page are recoverable in v1. POS is a
/// future reservation. Bullnym-backed products expose an automatic heal signal
/// rather than an unconditional reactivation prompt.
class KeychainManifestReservationSupport {
  const KeychainManifestReservationSupport._();

  static const _classifications =
      <String, KeychainManifestReservationClassification>{
        'btcpay_wallet_seed': KeychainManifestReservationClassification(
          exportableV1: true,
          recoverableV1: true,
          reactivationOnRecovery: KeychainManifestReactivationOnRecovery.none,
        ),
        // Registration is checked and silently repaired after local recovery.
        'lightning_address_wallet_seed':
            KeychainManifestReservationClassification(
              exportableV1: true,
              recoverableV1: true,
              reactivationOnRecovery:
                  KeychainManifestReactivationOnRecovery.autoHealOnRecoveryPr23,
            ),
        'payment_page_wallet_seed': KeychainManifestReservationClassification(
          exportableV1: true,
          recoverableV1: true,
          reactivationOnRecovery:
              KeychainManifestReactivationOnRecovery.autoHealOnRecoveryPr23,
        ),
      };

  /// The classification for a wallet-seed reservation, or null for a
  /// non-wallet-seed reservation or an unclassified one.
  static KeychainManifestReservationClassification? classificationFor(
    Bip85Reservation reservation,
  ) {
    if (reservation is! Bip85WalletSeedReservation) return null;
    return _classifications[reservation.id];
  }

  /// Whether restoring this reservation's wallet materialization requires the
  /// owning product's Bullnym registration to be checked and healed.
  static bool requiresProductReactivationOnRecovery(
    Bip85Reservation reservation,
  ) {
    return classificationFor(reservation)?.reactivationOnRecovery ==
        KeychainManifestReactivationOnRecovery.autoHealOnRecoveryPr23;
  }

  /// Whether the reserved seed is written into the v1 manifest backup
  /// (btcpay + lightning_address + payment_page - R2-KC3, decision [B]).
  static bool supportsV1Export(Bip85Reservation reservation) =>
      classificationFor(reservation)?.exportableV1 ?? false;

  /// Whether the reserved seed is materialized when restoring from a v1
  /// manifest at this stack level (BTCPay, Lightning Address, Payment Page).
  static bool supportsV1Recovery(Bip85Reservation reservation) =>
      classificationFor(reservation)?.recoverableV1 ?? false;

  /// Every explicitly classified wallet-seed reservation id, for the AD-4
  /// exhaustiveness test.
  static Set<String> get classifiedReservationIds =>
      _classifications.keys.toSet();
}
