import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_health_reminder_repository.dart';
import 'package:meta/meta.dart';

class EvaluateBackupHealthReminderUsecase {
  static final _milestoneSats = BigInt.from(10000000);

  final BackupHealthReminderRepository _repository;
  final DateTime Function() _clock;

  EvaluateBackupHealthReminderUsecase(
    this._repository, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  @useResult
  Future<Result<BackupHealthDecision?, BackupSettingsFailure>> execute({
    required List<Wallet> wallets,
    required int arkBalanceSat,
  }) async {
    final targetWallet = _targetWallet(wallets);
    if (targetWallet == null || targetWallet.masterFingerprint.isEmpty) {
      return const Ok(null);
    }

    final fingerprint = targetWallet.masterFingerprint;
    final seedWallets = wallets
        .where(
          (wallet) =>
              wallet.network.isMainnet &&
              wallet.masterFingerprint == fingerprint,
        )
        .toList();

    final posture = BackupHealthPosture.of(
      isEncryptedVaultTested: seedWallets.any(
        (wallet) => wallet.isEncryptedVaultTested,
      ),
      isPhysicalBackupTested: seedWallets.any(
        (wallet) => wallet.isPhysicalBackupTested,
      ),
    );
    if (posture == null) return const Ok(null);

    final vaultTestedAt = _latest([
      for (final wallet in seedWallets)
        if (wallet.isEncryptedVaultTested &&
            wallet.latestEncryptedBackup != null)
          wallet.latestEncryptedBackup!.toUtc(),
    ]);
    final physicalTestedAt = _latest([
      for (final wallet in seedWallets)
        if (wallet.isPhysicalBackupTested &&
            wallet.latestPhysicalBackup != null)
          wallet.latestPhysicalBackup!.toUtc(),
    ]);

    final BackupHealthReminderRecord record;
    switch (await _repository.fetch(fingerprint)) {
      case Ok(:final value):
        record = value;
      case Err(:final failure):
        return Err(failure);
    }

    // The stakes changing is worth interrupting for once per wallet, whatever
    // the schedule says.
    if (!record.crossedTenMillionSats &&
        _eligibleBalance(wallets, arkBalanceSat) >= _milestoneSats) {
      return Ok(
        BackupHealthDecision(
          masterFingerprint: fingerprint,
          posture: posture,
          trigger: BackupHealthTrigger.balanceMilestone,
          physicalBackupTestedAt: physicalTestedAt,
        ),
      );
    }

    // The schedule follows the clock of the thing being urged. Asking a
    // both-backups user to test their words must not be reset by a fresh
    // vault, and vice versa.
    final urgedTestedAt = posture.urgesPhysicalBackup
        ? vaultTestedAt
        : physicalTestedAt;
    final anchor = _latest([
      ?urgedTestedAt,
      ?record.lastAcknowledgedAt?.toUtc(),
    ]);
    final due = isBackupReminderDue(
      anchor: anchor,
      now: _clock().toUtc(),
      interval: posture.reminderInterval,
    );
    if (!due) return const Ok(null);

    return Ok(
      BackupHealthDecision(
        masterFingerprint: fingerprint,
        posture: posture,
        trigger: BackupHealthTrigger.scheduled,
        physicalBackupTestedAt: physicalTestedAt,
      ),
    );
  }

  Wallet? _targetWallet(List<Wallet> wallets) {
    for (final wallet in wallets) {
      if (wallet.isDefault &&
          wallet.network == Network.bitcoinMainnet &&
          wallet.signsLocally &&
          !wallet.isHardwareWallet) {
        return wallet;
      }
    }
    return null;
  }

  /// The balance at stake if this phone vanished: every mainnet wallet whose
  /// keys are on the device, plus Ark. Watch-only, watch-signer and hardware
  /// wallets recover from elsewhere, so they are excluded.
  BigInt _eligibleBalance(List<Wallet> wallets, int arkBalanceSat) {
    var total = BigInt.from(arkBalanceSat < 0 ? 0 : arkBalanceSat);
    for (final wallet in wallets) {
      if (wallet.network.isMainnet &&
          wallet.signsLocally &&
          !wallet.isHardwareWallet) {
        total += wallet.balanceSat;
      }
    }
    return total;
  }

  DateTime? _latest(Iterable<DateTime> timestamps) {
    DateTime? latest;
    for (final timestamp in timestamps) {
      if (latest == null || timestamp.isAfter(latest)) latest = timestamp;
    }
    return latest;
  }
}
