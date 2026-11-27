import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;

import 'access_inventory.dart';
import 'access_lock_policy.dart';

/// Joins the lifecycle policy to the inventory's lock. One per app.
final class AccessLockController {
  final AccessInventory _inventory;
  late final AccessLockPolicy policy;
  Future<bool>? _pendingLock;
  var _epoch = 0;
  var _foreground = false;
  var _resuming = false;
  var _resumeRequested = false;

  AccessLockController(this._inventory, {AccessLockPolicy? policy}) {
    this.policy = policy ?? AccessLockPolicy(onLock: lock);
  }

  Stream<bool> get locked => _inventory.locked;

  /// Revokes before waiting for any work already admitted.
  Future<void> lock() {
    _epoch++;
    final pending = _inventory.lock();
    _pendingLock = pending;
    return pending.then((_) {
      if (identical(_pendingLock, pending)) _pendingLock = null;
    });
  }

  LockSuspension suspendAutoLock(String reason) =>
      policy.suspendAutoLock(reason);

  void onLifecycle(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _epoch++;
      // Invalidate an unprotected reopen that is already awaiting storage.
      if (_resuming) unawaited(lock());
    }
    policy.onLifecycle(state);
    if (_foreground) _requestResume();
  }

  void _requestResume() {
    if (!_foreground || !_inventory.isLocked) return;
    if (_resuming) {
      _resumeRequested = true;
      return;
    }
    final epoch = _epoch;
    _resuming = true;
    unawaited(() async {
      try {
        await _pendingLock;
        if (!_foreground || epoch != _epoch) return;
        await _inventory.waitForDrain();
        if (_foreground && epoch == _epoch) {
          await _inventory.resumeUnprotected();
        }
      } finally {
        _resuming = false;
        if (_resumeRequested) {
          _resumeRequested = false;
          _requestResume();
        }
      }
    }());
  }
}
