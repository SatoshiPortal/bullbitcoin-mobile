import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';

/// PR23 forward-obligation for the auto-heal products, recorded as intent only
/// (there is no live reactivation field or flow at this stack level - DG-3).
enum KeychainManifestReactivationOnRecovery {
  /// Local materialization is sufficient; nothing to re-activate.
  none,

  /// A bullnym-backed product (LN address, Payment Page, POS). PR23 must, on
  /// recovery, look the registration up by the seed-derived npub and silently
  /// re-register if missing - NOT prompt unconditionally (DG-3/GATE-1).
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

  /// Materialized when restoring FROM a manifest at this stack level. Remote
  /// recovery is dormant and unwired until PR23, so only BTCPay (local
  /// materialization, no server dependency) recovers today.
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
/// PR23 FORWARD-OBLIGATION (DG-3, decisions [3]/[A]/[D]/[E]): at this stack
/// level LN (101) and Payment Page (102) are exportable but NOT recoverable -
/// remote recovery is dormant/unwired. When PR23 wires the recovery UI it MUST:
///   (a) flip `recoverableV1` to true for the auto-heal products
///       (101/102, and 103/POS once that reservation lands);
///   (b) implement the DG-3 auto-heal - verify the bullnym registration by
///       seed-derived npub and silently re-register if missing, keyed off
///       [KeychainManifestReactivationOnRecovery.autoHealOnRecoveryPr23];
///   (c) re-apply the KC-6 hidden + autosweep posture to those newly
///       recoverable products (as pr06 already does for BTCPay).
class KeychainManifestReservationSupport {
  const KeychainManifestReservationSupport._();

  static const _classifications =
      <String, KeychainManifestReservationClassification>{
        'btcpay_wallet_seed': KeychainManifestReservationClassification(
          exportableV1: true,
          recoverableV1: true,
          reactivationOnRecovery: KeychainManifestReactivationOnRecovery.none,
        ),
        'lightning_address_wallet_seed':
            KeychainManifestReservationClassification(
              exportableV1: true,
              recoverableV1: false,
              reactivationOnRecovery:
                  KeychainManifestReactivationOnRecovery.autoHealOnRecoveryPr23,
            ),
        'payment_page_wallet_seed': KeychainManifestReservationClassification(
          exportableV1: true,
          recoverableV1: false,
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

  /// Whether the reserved seed is written into the v1 manifest backup
  /// (btcpay + lightning_address + payment_page - R2-KC3, decision [B]).
  static bool supportsV1Export(Bip85Reservation reservation) =>
      classificationFor(reservation)?.exportableV1 ?? false;

  /// Whether the reserved seed is materialized when restoring from a v1
  /// manifest at this stack level (btcpay only; LN/page recovery is PR23).
  static bool supportsV1Recovery(Bip85Reservation reservation) =>
      classificationFor(reservation)?.recoverableV1 ?? false;

  /// Every explicitly classified wallet-seed reservation id, for the AD-4
  /// exhaustiveness test.
  static Set<String> get classifiedReservationIds =>
      _classifications.keys.toSet();
}
