import 'package:flutter/widgets.dart' show AppLifecycleState;

import 'access_inventory.dart';
import 'access_lock_policy.dart';

/// Joins the lifecycle policy to the inventory's lock. One per app.
final class AccessLockController {
  final AccessInventory _inventory;
  late final AccessLockPolicy policy;

  AccessLockController(this._inventory, {AccessLockPolicy? policy}) {
    this.policy = policy ?? AccessLockPolicy(onLock: lock);
  }

  Stream<bool> get locked => _inventory.locked;

  /// Locks a protected view now. Idempotent.
  Future<void> lock() async {
    await _inventory.lockIfProtected();
  }

  LockSuspension suspendAutoLock(String reason) =>
      policy.suspendAutoLock(reason);

  void onLifecycle(AppLifecycleState state) => policy.onLifecycle(state);
}
