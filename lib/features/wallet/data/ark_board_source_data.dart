import 'dart:async';

import 'package:bull_ark/ark_ui_setup.dart';
import 'package:bull_ark/bull_ark.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

import '../domain/network_x.dart';
import 'ark_display_data.dart';
import 'foreground_wallet_sync.dart';
import 'models/wallet_metadata_model.dart';
import 'wallet_metadata_datasource.dart';
import 'wallet_native_runtime.dart';

/// One explicitly scanned selection per foreground owner. No passive scan loop.
final class WalletArkBoardSourceData implements ArkBoardSourcePort {
  final WalletArkDisplayData _display;
  final ForegroundWalletSync _sync;
  final WalletNativeRuntime _runtime;
  final WalletMetadataDatasource _metadata;
  final ArkAccountId _account;
  final Future<Result<String, ArkFailure>> Function(ArkAccountId)
  _selectedSource;
  final bool Function() _isActive;
  late final StreamSubscription<void> _subscription;
  Future<Result<ArkDisplayData, ArkFailure>>? _flight;
  final _reads = <Future<Result<ArkDisplayData, ArkFailure>>>{};
  WalletRevision? _scan;
  ArkDisplayData? _published;
  int _epoch = 0;
  int _readEpoch = 0;
  bool _closed = false;

  WalletArkBoardSourceData({
    required this._display,
    required this._sync,
    required this._runtime,
    required this._metadata,
    required ArkAccountId account,
    required this._selectedSource,
    required this._isActive,
  }) : _account = account {
    _subscription = _display.changes(account).listen((_) {
      _published = null;
      if (_flight == null) ++_readEpoch;
    });
  }

  bool get _live => !_closed && _isActive();

  @override
  Stream<void> changes(ArkAccountId account) => _display.changes(account);

  @override
  bool accepts(ArkDisplayData observation) =>
      _live && _flight == null && identical(_published, observation);

  @override
  Future<Result<ArkDisplayData, ArkFailure>> refresh(ArkAccountId account) {
    if (!_live || account != _account) {
      return Future.value(const Err(ArkServiceUnavailableFailure()));
    }
    final running = _flight;
    if (running != null) return running;
    _scan = null;
    _published = null;
    final epoch = ++_epoch;
    return _flight = _refresh(
      account,
      epoch,
    ).whenComplete(() => _flight = null);
  }

  Future<Result<ArkDisplayData, ArkFailure>> _refresh(
    ArkAccountId account,
    int epoch,
  ) async {
    try {
      final selected = await _selectedSource(account);
      if (selected case Err(:final failure)) return Err(failure);
      final id = (selected as Ok<String, ArkFailure>).value;
      final row = await _metadata.fetch(id);
      if (!_live ||
          epoch != _epoch ||
          row == null ||
          row.seedFingerprint != account.parent ||
          row.network.shared != account.network) {
        return const Err(ArkAccountRecoveryFailure());
      }
      final scan = await _sync.synchronizeWithRevision(
        row,
        reason: SyncReason.manual,
      );
      if (!_live ||
          epoch != _epoch ||
          scan == null ||
          scan.key.id != id ||
          scan.key.network != account.network) {
        return const Err(ArkServiceUnavailableFailure());
      }
      _scan = scan;
      return await read(account);
    } on Exception {
      return const Err(ArkServiceUnavailableFailure());
    }
  }

  @override
  Future<Result<ArkDisplayData, ArkFailure>> read(ArkAccountId account) {
    final pending = _read(account, ++_readEpoch, _epoch);
    _reads.add(pending);
    return pending.whenComplete(() => _reads.remove(pending));
  }

  Future<Result<ArkDisplayData, ArkFailure>> _read(
    ArkAccountId account,
    int ticket,
    int epoch,
  ) async {
    try {
      return await _readCurrent(account, ticket, epoch);
    } on Exception {
      if (epoch == _epoch && ticket == _readEpoch) _published = null;
      return const Err(ArkServiceUnavailableFailure());
    }
  }

  Future<Result<ArkDisplayData, ArkFailure>> _readCurrent(
    ArkAccountId account,
    int ticket,
    int epoch,
  ) async {
    final scan = _scan;
    if (!_live || account != _account || scan == null) {
      return const Err(ArkServiceUnavailableFailure());
    }
    final before = await _runtime.readRevision(scan.key);
    final result = await _display.readAfterScan(account, scan);
    final selected = await _selectedSource(account);
    final current = await _runtime.readRevision(scan.key);
    // A superseded reader owns no current state, including invalidation.
    if (epoch != _epoch || ticket != _readEpoch) {
      return const Err(ArkServiceUnavailableFailure());
    }
    if (!_live ||
        selected is! Ok<String, ArkFailure> ||
        selected.value != scan.key.id ||
        current is! Ok<WalletRevisionState, SyncFailure> ||
        before is! Ok<WalletRevisionState, SyncFailure> ||
        current.value.lifecycle != WalletLifecycle.active ||
        current.value.syncFailed ||
        current.value.stamp.key != scan.key ||
        current.value.stamp.generation != scan.generation ||
        current.value.stamp.revision < scan.revision) {
      _scan = null;
      _published = null;
      return const Err(ArkServiceUnavailableFailure());
    }
    if (before.value.stamp != current.value.stamp) {
      // A same-generation revision retires this observation, not the scan.
      _published = null;
      return const Err(ArkServiceUnavailableFailure());
    }
    _published = switch (result) {
      Ok(:final value) => value,
      Err() => null,
    };
    return result;
  }

  Future<void> close() async {
    _closed = true;
    ++_epoch;
    _published = null;
    await _subscription.cancel();
    await _flight;
    await Future.wait(_reads);
  }
}
