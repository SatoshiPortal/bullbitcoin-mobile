import 'dart:io';
import 'dart:ui';

import 'package:ark/ark_setup.dart' as native;
import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/settings/data/settings_datasource.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/data/ark_transaction_verifier.dart';
import 'package:bull_ark/ark_maintenance_setup.dart';
import 'package:bull_ark/ark_notification_setup.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bull_ark/bull_ark.dart';
import 'package:notifications/notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// Only existing stores are opened. Every resource remains alive until the
/// admitted native work has completed and the runner closes its resources.
Future<BackgroundTaskHandler> setupArkBackgroundTask(
  BackgroundTaskResources resources,
  Directory documents,
) async {
  if (!await SqliteDatabase.isAtCurrentSchema()) {
    return () async => const BackgroundTaskExecutionResult.retry();
  }
  final sqlite = SqliteDatabase();
  resources.onClose(sqlite.close);
  final settings = SettingsRepository(
    settingsDatasource: SettingsDatasource(sqlite: sqlite),
  );
  resources.onClose(settings.close);
  final preferences = await settings.fetch();
  if (preferences.environment != Environment.regtest) {
    return () async => const BackgroundTaskExecutionResult.retry();
  }
  final directory = '${documents.path}/ark';
  final registry = switch (SqliteArkAccountRegistry.open(
    '$directory/accounts.sqlite',
    foreground: false,
  )) {
    Ok(:final value) => value,
    Err() => throw StateError('Ark account inventory unavailable'),
  };
  resources.onClose(registry.close);
  final locale = preferences.language?.locale ?? const Locale('en');
  final copy = arkExpiryCopy(locale);
  final initialized = await initializeArkNotifications(locale);
  final notification = switch (initialized) {
    Ok(:final value) => value,
    Err() => scheduledNotifications(
      channelId: arkExpiryChannelId,
      channelName: copy.title,
    ),
  };
  final opened = SqliteArkReminderRepository.open(
    path: '$directory/reminders.sqlite',
    notifications: notification,
    title: copy.title,
    body: copy.body,
    foreground: false,
  );
  ArkReminderRepository reminders = const _UnavailableReminders();
  var reminderFailure = initialized is Err;
  if (opened case Ok(:final value)) {
    reminders = value;
    resources.onClose(value.close);
    if (await value.reapplyStored() case Err()) reminderFailure = true;
  } else {
    reminderFailure = true;
  }
  final budget = ArkBackgroundStageBudget(() => resources.mayAdmitNextStage);
  final secrets = Secrets(
    scratchDirectory: () async => (await getTemporaryDirectory()).path,
  );
  final client = createArkNativeClient(
    storagePath: '$directory/native',
    childProvider: SecretsArkChildProvider(secrets, registry),
    transactionVerifier: const ArkTransactionVerifier(),
    executionPolicy: const _RegtestBackgroundPolicy(),
    executionMode: native.ArkExecutionMode.backgroundExisting,
    stageBudget: budget,
  );
  resources.onClose(client.close);
  final handler = ArkMaintenance(
    client: client,
    reminders: reminders,
    accounts: registry,
    budget: budget,
  ).backgroundHandler();
  return () async {
    final result = await handler();
    return reminderFailure
        ? const BackgroundTaskExecutionResult.retry()
        : result;
  };
}

final class _RegtestBackgroundPolicy implements native.ArkExecutionPolicyPort {
  const _RegtestBackgroundPolicy();

  @override
  bool mayRun(ArkAccountId account, native.ArkExecutionMode mode) =>
      account.network == BitcoinNetwork.regtest &&
      mode == native.ArkExecutionMode.backgroundExisting;
}

/// Failure stays visible to the runner without blocking saved-claim delivery.
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
