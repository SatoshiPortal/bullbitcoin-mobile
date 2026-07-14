import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_health_reminder_repository.dart';
import 'package:meta/meta.dart';

class EvaluateBackupHealthReminderUsecase {
  static final _oneMillionSats = BigInt.from(1000000);
  static final _tenMillionSats = BigInt.from(10000000);
  static const _recurrence = Duration(days: 90);

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
    final hasRecoverbull = seedWallets.any(
      (wallet) => wallet.isEncryptedVaultTested,
    );
    final hasPhysical = seedWallets.any(
      (wallet) => wallet.isPhysicalBackupTested,
    );

    if (!hasRecoverbull && !hasPhysical) return const Ok(null);

    final posture = switch ((hasRecoverbull, hasPhysical)) {
      (true, false) => BackupHealthPosture.recoverbullOnly,
      (false, true) => BackupHealthPosture.physicalOnly,
      (true, true) => BackupHealthPosture.both,
      (false, false) => throw StateError('No verified backup'),
    };

    final backupTimestamps = <DateTime>[
      for (final wallet in seedWallets)
        if (wallet.isEncryptedVaultTested &&
            wallet.latestEncryptedBackup != null)
          wallet.latestEncryptedBackup!.toUtc(),
      for (final wallet in seedWallets)
        if (wallet.isPhysicalBackupTested &&
            wallet.latestPhysicalBackup != null)
          wallet.latestPhysicalBackup!.toUtc(),
    ];
    final latestBackupAt = _latest(backupTimestamps);
    BackupHealthReminderRecord record;
    switch (await _repository.fetch(fingerprint)) {
      case Ok(:final value):
        record = value;
      case Err(:final failure):
        return Err(failure);
    }

    if (record.pendingActionStartedAt != null) {
      final actionCompleted =
          latestBackupAt != null &&
          !latestBackupAt.isBefore(record.pendingActionStartedAt!.toUtc());
      record = record.copyWith(
        highestHandledBalanceTier: actionCompleted
            ? BackupBalanceTier.highest(
                record.highestHandledBalanceTier,
                record.pendingActionBalanceTier,
              )
            : record.highestHandledBalanceTier,
        clearPendingAction: true,
      );
      if (await _repository.save(record) case Err(:final failure)) {
        return Err(failure);
      }
    }

    final currentTier = _balanceTier(_eligibleBalance(wallets, arkBalanceSat));
    if (currentTier.isHigherThan(record.highestHandledBalanceTier)) {
      return Ok(
        BackupHealthDecision(
          masterFingerprint: fingerprint,
          posture: posture,
          trigger: BackupHealthTrigger.balanceMilestone,
          currentBalanceTier: currentTier,
        ),
      );
    }

    final acknowledgedAt = record.lastAcknowledgedAt?.toUtc();
    final anchor = _latest([?latestBackupAt, ?acknowledgedAt]);
    final now = _clock().toUtc();
    final scheduled =
        anchor == null ||
        anchor.isAfter(now) ||
        !now.isBefore(anchor.add(_recurrence));
    if (!scheduled) return const Ok(null);

    return Ok(
      BackupHealthDecision(
        masterFingerprint: fingerprint,
        posture: posture,
        trigger: BackupHealthTrigger.scheduled,
        currentBalanceTier: currentTier,
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

  BackupBalanceTier _balanceTier(BigInt balance) {
    if (balance > _tenMillionSats) return BackupBalanceTier.tenMillion;
    if (balance > _oneMillionSats) return BackupBalanceTier.oneMillion;
    return BackupBalanceTier.none;
  }

  DateTime? _latest(Iterable<DateTime> timestamps) {
    DateTime? latest;
    for (final timestamp in timestamps) {
      if (latest == null || timestamp.isAfter(latest)) latest = timestamp;
    }
    return latest;
  }
}
