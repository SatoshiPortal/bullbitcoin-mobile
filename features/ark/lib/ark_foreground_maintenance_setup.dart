/// Foreground setup for durable Ark safety reminders and renewal.
library;

import 'dart:ui';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:primitives/primitives.dart';

import 'ark_maintenance_setup.dart';
import 'ark_notification_setup.dart';
import 'src/domain/ark_failure.dart';
import 'src/domain/ark_expiry_warning.dart';
import 'src/domain/repositories/ark_reminder_repository.dart';
import 'src/domain/repositories/ark_account_registry_repository.dart';

final class ArkForegroundMaintenance {
  final SqliteArkReminderRepository? _reminders;
  final ArkMaintenance _maintenance;
  final Set<Future<Result<void, ArkFailure>>> _active = {};
  bool _closing = false;

  /// Whether previously stored notifications were successfully restored.
  final bool remindersReady;

  ArkForegroundMaintenance._(
    this._reminders,
    this._maintenance,
    this.remindersReady,
  );

  /// The caller retains the client and registry until this pass and close end.
  Future<Result<void, ArkFailure>> run(ArkAccountId account) async {
    if (_closing) return const Err(ArkServiceUnavailableFailure());
    final pass = _maintenance.runForeground(account);
    _active.add(pass);
    try {
      return await pass;
    } finally {
      _active.remove(pass);
    }
  }

  Future<void> close() async {
    _closing = true;
    try {
      await Future.wait(_active.toList());
    } finally {
      await _reminders?.close();
    }
  }
}

/// [initializeNew] requires explicit first-setup authority. Restarting an
/// established installation must use false and cannot recreate a lost ledger.
Future<Result<ArkForegroundMaintenance, ArkFailure>>
openArkForegroundMaintenance({
  required String path,
  required Locale locale,
  required ArkClient client,
  required ArkAccountRegistryRepository accounts,
  required bool initializeNew,
}) async {
  final copy = arkExpiryCopy(locale);
  final initialized = await initializeArkNotifications(locale);
  final notification = switch (initialized) {
    Ok(:final value) => value,
    Err() => unavailableArkNotifications(),
  };
  final opened = SqliteArkReminderRepository.open(
    path: path,
    notifications: notification,
    title: copy.title,
    body: copy.body,
    foreground: true,
    initializeNew: initializeNew,
  );
  SqliteArkReminderRepository? store;
  ArkReminderRepository reminders = const _UnavailableReminders();
  var ready = false;
  if (opened case Ok(:final value)) {
    store = value;
    reminders = value;
    final restored = await value.reapplyStored();
    ready = initialized is Ok && restored is Ok;
  }
  return Ok(
    ArkForegroundMaintenance._(
      store,
      ArkMaintenance(
        client: client,
        reminders: reminders,
        accounts: accounts,
        budget: const ArkUnlimitedStageBudget(),
      ),
      ready,
    ),
  );
}

final class _UnavailableReminders implements ArkReminderRepository {
  const _UnavailableReminders();

  @override
  Future<Result<void, ArkFailure>> reconcile({
    required ArkAccountId account,
    required ArkExpiryWarning? warning,
    required bool authoritativeEmpty,
    required int revision,
    required int tipHeight,
    ArkReminderPolicyEvidence? policyEvidence,
  }) async => const Err(ArkFeatureStorageFailure());
}
