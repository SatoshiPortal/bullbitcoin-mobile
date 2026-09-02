import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_preferences_failure.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_backup_failure.dart';

DateTime _systemNowUtc() => DateTime.now().toUtc();

typedef ReadFrozenOutpoints = Future<List<FrozenWalletOutpoint>> Function();
typedef RestoreFrozenOutpoints =
    Future<void> Function(List<FrozenWalletOutpoint> outpoints);
typedef ReadWalletPreferences =
    Future<Result<List<WalletPreferences>, WalletPreferencesFailure>>
    Function();
typedef ApplyWalletPreferences =
    Future<
      Result<WalletPreferencesRecoveryApplyResult, WalletPreferencesFailure>
    >
    Function(List<WalletPreferencesRecoveryUpdate> updates);
typedef ReadPortableSettings = Future<WalletPortableSettings> Function();
typedef RestorePortableSettings =
    Future<void> Function(WalletPortableSettings settings);

/// The one owner of the backup's protected-data section: it reads the local
/// snapshot, restores a recovered one, and reports when its inputs change.
final class WalletMetadataBackupImpl {
  final LabelsFacade _labels;
  final ReadFrozenOutpoints _getFrozenOutpoints;
  final RestoreFrozenOutpoints _restoreFrozenOutpoints;
  final ReadWalletPreferences _getPreferences;
  final ApplyWalletPreferences _applyPreferences;
  final ReadPortableSettings readPortableSettings;
  final RestorePortableSettings restorePortableSettings;
  final DateTime Function() _nowUtc;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final List<StreamSubscription<void>> _subscriptions = [];
  bool _suppressChanges = false;
  bool _changedWhileSuppressed = false;

  WalletMetadataBackupImpl({
    required this._labels,
    required this._getFrozenOutpoints,
    required this._restoreFrozenOutpoints,
    required this._getPreferences,
    required this._applyPreferences,
    required this.readPortableSettings,
    required this.restorePortableSettings,
    required List<Stream<void>> changeStreams,
    this._nowUtc = _systemNowUtc,
  }) {
    for (final stream in changeStreams) {
      _subscriptions.add(stream.listen((_) => _notifyChanged()));
    }
  }

  Stream<void> get changes => _changes.stream;

  Result<void, WalletMetadataBackupFailure> validate(
    WalletMetadataSnapshot snapshot,
  ) => _hasUnusableLabel(snapshot)
      ? const Err(WalletMetadataBackupEncodingFailure())
      : const Ok(null);

  bool _hasUnusableLabel(WalletMetadataSnapshot snapshot) =>
      snapshot.labels.any(
        (label) => !_labels.isValid(
          NewLabel(
            type: label.type,
            reference: label.reference,
            label: label.label,
            origin: label.origin,
          ),
        ),
      );

  Future<Result<WalletMetadataSnapshot, WalletMetadataBackupFailure>>
  localSnapshot() async {
    try {
      final labelsResult = await _labels.fetchAllStrict();
      final List<Label> labels;
      switch (labelsResult) {
        case Ok(:final value):
          labels = value;
        case Err():
          return const Err(WalletMetadataBackupReadFailure());
      }
      final preferencesResult = await _getPreferences();
      final List<WalletPreferences> preferences;
      switch (preferencesResult) {
        case Ok(:final value):
          preferences = value
              .where((item) => item.hasRepresentedValue)
              .toList(growable: false);
        case Err():
          return const Err(WalletMetadataBackupReadFailure());
      }
      final snapshot = WalletMetadataSnapshot(
        labels: labels
            .map(
              (label) => WalletMetadataLabel(
                type: label.type,
                reference: label.reference,
                label: label.label,
                origin: label.origin,
              ),
            )
            .toList(growable: false),
        frozenOutpoints: await _getFrozenOutpoints(),
        walletPreferences: preferences,
        settings: await readPortableSettings(),
      );
      return Ok(snapshot);
    } on Exception catch (_, trace) {
      _logFailure('read', trace);
      return const Err(WalletMetadataBackupReadFailure());
    }
  }

  Future<Result<bool, WalletMetadataBackupFailure>> recover({
    required WalletMetadataSnapshot snapshot,
    required Set<String> createdWalletRefs,
    DateTime? deadline,
  }) async {
    _suppressChanges = true;
    try {
      _checkDeadline(deadline);
      if (_hasUnusableLabel(snapshot)) {
        return const Err(WalletMetadataBackupEncodingFailure());
      }
      final labelsResult = await _restoreLabels(snapshot.labels);
      final bool labelsComplete;
      switch (labelsResult) {
        case Ok(:final value):
          labelsComplete = value;
        case Err(:final failure):
          return Err(failure);
      }
      _checkDeadline(deadline);
      await _restoreFrozenOutpoints(snapshot.frozenOutpoints);
      _checkDeadline(deadline);
      final preferencesResult = await _restorePreferences(
        snapshot.walletPreferences,
        createdWalletRefs,
      );
      final bool preferencesComplete;
      switch (preferencesResult) {
        case Ok(:final value):
          preferencesComplete = value;
        case Err(:final failure):
          return Err(failure);
      }
      _checkDeadline(deadline);
      await restorePortableSettings(snapshot.settings);
      _checkDeadline(deadline);
      return Ok(labelsComplete && preferencesComplete);
    } on TimeoutException {
      rethrow;
    } on Exception catch (_, trace) {
      _logFailure('recover', trace);
      return const Err(WalletMetadataBackupWriteFailure());
    } finally {
      _suppressChanges = false;
      if (_changedWhileSuppressed) {
        _changedWhileSuppressed = false;
        if (!_changes.isClosed) _changes.add(null);
      }
    }
  }

  Future<Result<bool, WalletMetadataBackupFailure>> _restoreLabels(
    List<WalletMetadataLabel> desired,
  ) async {
    final currentResult = await _labels.fetchAllStrict();
    final List<Label> current;
    switch (currentResult) {
      case Ok(:final value):
        current = value;
      case Err():
        return const Err(WalletMetadataBackupReadFailure());
    }
    final currentByIdentity = {
      for (final label in current)
        _labelIdentity(label.label, label.reference): label,
    };
    var complete = true;
    for (final label in desired) {
      final existing =
          currentByIdentity[_labelIdentity(label.label, label.reference)];
      if (existing != null) {
        if (existing.type != label.type || existing.origin != label.origin) {
          complete = false;
        }
        continue;
      }
      final stored = await _labels.store(
        NewLabel(
          type: label.type,
          reference: label.reference,
          label: label.label,
          origin: label.origin,
        ),
      );
      if (stored case Err()) {
        return const Err(WalletMetadataBackupWriteFailure());
      }
    }
    return Ok(complete);
  }

  Future<Result<bool, WalletMetadataBackupFailure>> _restorePreferences(
    List<WalletPreferences> desired,
    Set<String> createdWalletRefs,
  ) async {
    final currentResult = await _getPreferences();
    final List<WalletPreferences> current;
    switch (currentResult) {
      case Ok(:final value):
        current = value;
      case Err():
        return const Err(WalletMetadataBackupReadFailure());
    }
    final currentByWallet = {for (final item in current) item.walletRef: item};
    final updates = <WalletPreferencesRecoveryUpdate>[];
    var complete = true;
    for (final recovered in desired) {
      final existing = currentByWallet[recovered.walletRef];
      if (existing != null && _samePreferences(existing, recovered)) {
        updates.add(
          WalletPreferencesRecoveryUpdate(
            expected: existing,
            recovered: recovered,
          ),
        );
        continue;
      }
      if (existing != null && createdWalletRefs.contains(recovered.walletRef)) {
        updates.add(
          WalletPreferencesRecoveryUpdate(
            expected: existing,
            recovered: recovered,
          ),
        );
      } else {
        complete = false;
      }
    }
    final appliedResult = await _applyPreferences(updates);
    switch (appliedResult) {
      case Ok(:final value):
        final expected = updates
            .map((item) => item.recovered.walletRef)
            .toSet();
        final reported = value.appliedWalletRefs.union(
          value.conflictedWalletRefs,
        );
        if (reported.length != expected.length ||
            !reported.containsAll(expected)) {
          throw StateError('Wallet preference restore result is incomplete');
        }
        return Ok(complete && value.conflictedWalletRefs.isEmpty);
      case Err():
        return const Err(WalletMetadataBackupWriteFailure());
    }
  }

  void _notifyChanged() {
    if (_suppressChanges) {
      _changedWhileSuppressed = true;
    } else if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  void _checkDeadline(DateTime? deadline) {
    if (deadline != null && !_nowUtc().isBefore(deadline)) {
      throw TimeoutException('wallet metadata recovery deadline');
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _changes.close();
  }
}

String _labelIdentity(String label, String reference) =>
    '$label\u0000$reference';

bool _samePreferences(WalletPreferences left, WalletPreferences right) =>
    left.walletRef == right.walletRef &&
    left.label == right.label &&
    left.hideOnHome == right.hideOnHome &&
    left.autoSweepEnabled == right.autoSweepEnabled;

void _logFailure(String operation, StackTrace trace) {
  log.severe(
    message: 'Failed to $operation protected wallet data',
    error: StateError('protected wallet data $operation failed'),
    trace: trace,
  );
}
