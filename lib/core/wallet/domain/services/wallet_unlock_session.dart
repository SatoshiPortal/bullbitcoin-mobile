import 'dart:async';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';

/// The wallet domain's single private signing-material session.
///
/// Internal to `lib/core/wallet`: everything outside it reaches this state
/// through [WalletSigningMaterialResolver] and the wallet public facade, never
/// by holding the session itself (spec F13).
final class WalletUnlockSession {
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  String? _walletId;
  MnemonicSeed? _seed;
  bool _pendingResumeNavigation = false;
  var _mountGeneration = 0;

  String? get unlockedWalletId => _walletId;

  Stream<void> get changes => _changes.stream;

  bool isUnlocked(String walletId) => _walletId == walletId && _seed != null;

  MnemonicSeed seedFor(String walletId) {
    final seed = _seed;
    if (_walletId != walletId || seed == null) {
      throw PassphraseWalletLockedException(walletId);
    }
    return seed;
  }

  int beginMount() => ++_mountGeneration;

  void cancelMount() => _mountGeneration++;

  bool unlockIfCurrent({
    required int generation,
    required String walletId,
    required MnemonicSeed seed,
  }) {
    if (generation != _mountGeneration) return false;
    _clearSeedBytes();
    _walletId = walletId;
    _seed = seed;
    _changes.add(null);
    return true;
  }

  bool lock() {
    cancelMount();
    if (_walletId == null && _seed == null) return false;
    _clearSeedBytes();
    _walletId = null;
    _changes.add(null);
    return true;
  }

  /// Lock driven by the app losing the foreground.
  ///
  /// Clears the seed immediately and records that the user is owed a return to
  /// the locked Passphrase page, which the lifecycle owner collects with
  /// [takePendingResumeNavigation] once the app resumes (decision 5). Locks
  /// from any other cause — forgetting a wallet, loading another one — use
  /// [lock] and request no navigation.
  bool lockForBackground() {
    if (!lock()) return false;
    _pendingResumeNavigation = true;
    return true;
  }

  /// Consumes the pending return-to-Passphrase request, so a single background
  /// lock navigates exactly once.
  bool takePendingResumeNavigation() {
    final pending = _pendingResumeNavigation;
    _pendingResumeNavigation = false;
    return pending;
  }

  void _clearSeedBytes() {
    final seed = _seed;
    _seed = null;
    seed?.bytes.fillRange(0, seed.bytes.length, 0);
  }

  Future<void> close() async {
    lock();
    await _changes.close();
  }
}
