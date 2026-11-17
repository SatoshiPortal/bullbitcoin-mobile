/// Privileged maintenance composition for foreground and headless hosts.
library;

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:primitives/primitives.dart';

import 'src/data/ark_background_task.dart';
import 'src/data/ark_repository_impl.dart';
import 'src/domain/ark_failure.dart';
import 'src/domain/repositories/ark_account_registry_repository.dart';
import 'src/domain/repositories/ark_reminder_repository.dart';
import 'src/domain/usecases/read_ark_usecase.dart';
import 'src/domain/usecases/run_ark_background_usecase.dart';
import 'src/domain/usecases/update_ark_expiry_warning_usecase.dart';

export 'src/data/sqlite_ark_reminder_repository.dart';

/// Runs the same protective pass in either execution mode. The host owns the
/// client and reminder store and must await their closure after admitted work.
final class ArkMaintenance {
  final ArkRepositoryImpl _repository;
  final ArkReminderRepository reminders;
  final ArkAccountRegistryRepository accounts;
  final ArkStageBudget budget;

  ArkMaintenance({
    required ArkClient client,
    required this.reminders,
    required this.accounts,
    required this.budget,
  }) : _repository = ArkRepositoryImpl(client);

  RunArkBackgroundUsecase get _renew => RunArkBackgroundUsecase(
    SynchronizeArkUsecase(_repository),
    UpdateArkExpiryWarningUsecase(reminders),
  );

  Future<Result<void, ArkFailure>> runForeground(ArkAccountId account) =>
      _renew.execute(account);

  BackgroundTaskHandler backgroundHandler() => arkRenewalHandler(
    usecase: RunArkBackgroundTaskUsecase(
      accounts,
      budget,
      RunArkSavedClaimsUsecase(_repository, budget),
      _renew,
    ),
  );
}

/// Schedule only from an authoritative registry observation. A failed read
/// must leave an existing safety schedule in place.
Future<Result<void, ArkFailure>> scheduleArkMaintenance({
  required ArkAccountRegistryRepository accounts,
  required BackgroundTaskDispatcher dispatcher,
  BackgroundTaskSchedulerPort? scheduler,
}) async {
  switch (await accounts.list()) {
    case Err(:final failure):
      return Err(failure);
    case Ok(:final value):
      try {
        await applyArkRenewalSchedule(
          dispatcher: dispatcher,
          renewalRequired: value.isNotEmpty,
          scheduler: scheduler,
        );
        return const Ok(null);
      } on Exception {
        return const Err(ArkServiceUnavailableFailure());
      }
  }
}
