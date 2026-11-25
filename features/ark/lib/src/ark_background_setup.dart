import 'package:legacy_storage/coordination.dart';
import 'package:preferences/preferences.dart'
    show Preferences, PreferencesFailure;

import 'dart:io';
import 'dart:ui';

import '../ark_maintenance_setup.dart';
import '../ark_notification_setup.dart';
import '../ark_setup.dart';
import '../ark_wallet_setup.dart';
import '../bull_ark.dart';

import 'package:ark/ark_setup.dart' as native;
import 'package:background_tasks/background_tasks.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:ark/ark.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:notifications/payment_store.dart';
import 'package:notifications/notifications.dart'
    show ScheduledNotificationPort;

import 'data/ark_exit_notifier.dart';
import 'data/ark_payment_observer.dart';

/// Only existing stores are opened. Every resource remains alive until the
/// admitted native work has completed and the runner closes its resources.
Future<BackgroundTaskHandler> setupArkBackgroundTask(
  BackgroundTaskResources resources,
  Directory documents, {
  required File preferencesFile,
  @visibleForTesting
  Future<Result<Preferences, PreferencesFailure>> Function(
    File,
    RuntimeAdmission,
    SqliteDatabase,
  )?
  openPreferences,
  @visibleForTesting
  ArkClient Function(native.ArkExecutionPolicyPort, native.ArkStageBudget)?
  existingClient,
}) async {
  final admission = resources.storageAdmission;
  if (admission == null) {
    return () async => const BackgroundTaskExecutionResult.retry();
  }
  if (!await SqliteDatabase.isAtCurrentSchema()) {
    return () async => const BackgroundTaskExecutionResult.retry();
  }
  final sqlite = await LegacySourceStore(
    source: LegacySource(
      File('${documents.path}/bullbitcoin_sqlite.sqlite'),
      SqliteDatabase.currentSchemaVersion,
    ),
    create: SqliteDatabase.new,
  ).open(admission);
  final openedPreferences = openPreferences == null
      ? await Preferences.open(
          file: preferencesFile,
          admission: admission,
          legacyDatabase: sqlite,
        )
      : await openPreferences(preferencesFile, admission, sqlite);
  if (openedPreferences case Err()) {
    return () async => const BackgroundTaskExecutionResult.retry();
  }
  final settings =
      (openedPreferences as Ok<Preferences, PreferencesFailure>).value;
  resources.onClose(settings.close);
  final language = (await settings.readLanguage()).fold(
    (value) => value,
    (failure) => throw Exception('Preferences read failed'),
  );
  // Browsing another network does not retire captured regtest obligations.
  final directory = '${documents.path}/ark';
  final registry = switch (SqliteArkAccountRegistry.open(
    '$directory/accounts.sqlite',
    foreground: false,
  )) {
    Ok(:final value) => value,
    Err() => throw StateError('Ark account inventory unavailable'),
  };
  resources.onClose(registry.close);
  final locale = language == null
      ? const Locale('en')
      : Locale.fromSubtags(
          languageCode: language.languageCode,
          scriptCode: language.scriptCode,
          countryCode: language.countryCode,
        );
  final copy = arkExpiryCopy(locale);
  final initialized = await initializeArkNotifications(locale);
  final notification = switch (initialized) {
    Ok(:final value) => value,
    Err() => unavailableArkNotifications(),
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
  final exitNotifier = _BackgroundExitObserver(
    documents: documents.path,
    directory: directory,
    locale: locale,
    notifications: notification,
    budget: budget,
  );
  resources.onClose(exitNotifier.close);
  final secrets = Secrets(
    scratchDirectory: () async => (await getTemporaryDirectory()).path,
  );
  // Headless work never provisions or migrates the source authority.
  final sourceAuthority = SqliteArkFundingReservations.open(
    '${documents.path}/ark-funding.sqlite',
    foreground: false,
  );
  if (sourceAuthority case Ok(:final value)) resources.onClose(value.close);
  const policy = _RegtestBackgroundPolicy();
  final client =
      existingClient?.call(policy, budget) ??
      createArkNativeClient(
        storagePath: '$directory/native',
        childProvider: SecretsArkChildProvider(secrets, registry),
        transactionVerifier: const ArkTransactionVerifier(),
        boardAbandonment: WalletArkBoardAbandonment(sourceAuthority),
        executionPolicy: policy,
        executionMode: native.ArkExecutionMode.backgroundExisting,
        stageBudget: budget,
        exitObserver: exitNotifier,
      );
  resources.onClose(client.close);
  final handler = ArkMaintenance(
    client: client,
    reminders: reminders,
    accounts: _ExistingRegtestAccounts(registry, policy),
    budget: budget,
  ).backgroundHandler();
  return () async {
    final result = await handler();
    return reminderFailure || exitNotifier.failed
        ? const BackgroundTaskExecutionResult.retry()
        : result;
  };
}

/// Saved claims run before opening the notification ledger.
final class _BackgroundExitObserver implements native.ArkExitObserverPort {
  final String documents;
  final String directory;
  final Locale locale;
  final ScheduledNotificationPort notifications;
  final native.ArkStageBudget budget;
  final List<Future<void> Function()> _cleanup = [];
  Future<native.ArkExitObserverPort>? _opening;
  bool failed = false;

  _BackgroundExitObserver({
    required this.documents,
    required this.directory,
    required this.locale,
    required this.notifications,
    required this.budget,
  });

  Future<native.ArkExitObserverPort> _open() => _opening ??= () async {
    final allocator = await PaymentNotifications.initializeBackground(
      documents,
      locale,
      _cleanup.add,
    );
    if (allocator == null) {
      throw const FormatException('Notification store unavailable');
    }
    final copy = arkExitClaimableCopy(locale);
    final observer = ArkExitNotifier.open(
      path: '$directory/exit-notices.sqlite',
      foreground: false,
      allocator: allocator,
      notifications: notifications,
      budget: budget,
      title: copy.title,
      body: copy.body,
    );
    _cleanup.add(() async => observer.close());
    return ArkPaymentObserver(
      notifications: allocator,
      exits: observer,
      foreground: false,
      copy: PaymentNotifications.copy(locale),
    );
  }();

  Future<void> close() async {
    Object? failure;
    StackTrace? trace;
    for (var index = _cleanup.length - 1; index >= 0; index--) {
      try {
        await _cleanup[index]();
        _cleanup.removeAt(index);
      } catch (error, stack) {
        failure ??= error;
        trace ??= stack;
      }
    }
    if (failure != null && trace != null) {
      Error.throwWithStackTrace(failure, trace);
    }
  }

  @override
  Future<void> observe(ArkPassOutcome outcome) async {
    try {
      await (await _open()).observe(outcome);
    } on Exception {
      failed = true;
      rethrow;
    }
  }

  @override
  Future<void> claimAdmitted(ArkAccountId account, ArkOperation claim) async {
    try {
      await (await _open()).claimAdmitted(account, claim);
    } on Exception {
      failed = true;
      rethrow;
    }
  }
}

final class _RegtestBackgroundPolicy implements native.ArkExecutionPolicyPort {
  const _RegtestBackgroundPolicy();

  @override
  bool mayRun(ArkAccountId account, native.ArkExecutionMode mode) =>
      account.network == BitcoinNetwork.regtest &&
      mode == native.ArkExecutionMode.backgroundExisting;
}

/// Filter persisted identities before either lane, as well as native admission.
/// The same canonical capability check also applies to a substituted client.
final class _ExistingRegtestAccounts implements ArkAccountRegistryRepository {
  final ArkAccountRegistryRepository _registry;
  final native.ArkExecutionPolicyPort _policy;
  const _ExistingRegtestAccounts(this._registry, this._policy);

  @override
  Future<Result<List<ArkAccountConfig>, ArkFailure>> list() async =>
      (await _registry.list()).map(
        (accounts) => accounts
            .where(
              (config) =>
                  NetworkCapabilities.supports(
                    config.id.network,
                    NetworkCapability.ark,
                  ) &&
                  _policy.mayRun(
                    config.id,
                    native.ArkExecutionMode.backgroundExisting,
                  ),
            )
            .toList(),
      );

  @override
  Future<Result<void, ArkFailure>> publish(ArkAccountConfig config) async =>
      const Err(ArkServiceUnavailableFailure());
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
