/// Privileged maintenance composition for foreground and headless hosts.
library;

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:primitives/primitives.dart';

import 'src/data/ark_background_task.dart';
import 'src/data/ark_repository_impl.dart';
import 'src/domain/ark_exit_funding.dart';
import 'src/domain/ark_failure.dart';
import 'src/domain/ark_reserve_top_up_port.dart';
import 'src/domain/repositories/ark_account_registry_repository.dart';
import 'src/domain/repositories/ark_reminder_repository.dart';
import 'src/domain/usecases/run_ark_exits_usecase.dart';
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

  /// Pays waiting exits' fees from Secure Bitcoin; foreground only.
  final ArkReserveTopUpPort? _exitTopUp;

  /// What waiting exits need, for the screens to show.
  final ArkExitFunding? _exitFunding;

  ArkMaintenance({
    required ArkClient client,
    required this.reminders,
    required this.accounts,
    required this.budget,
    this._exitTopUp,
    this._exitFunding,
  }) : _repository = ArkRepositoryImpl(client);

  RunArkBackgroundUsecase get _renew => RunArkBackgroundUsecase(
    SynchronizeArkUsecase(_repository),
    UpdateArkExpiryWarningUsecase(reminders),
  );

  /// Delivery, then renewal, then exits: the exit pass reads the observation
  /// renewal just refreshed. Each lane runs whatever the others returned; the
  /// first failure is reported.
  Future<Result<void, ArkFailure>> runForeground(ArkAccountId account) async {
    final delivery = await RunArkSavedClaimsUsecase(
      _repository,
      budget,
    ).execute(account);
    final renewal = await _renew.execute(account);
    final exits = await runExits(account);
    if (delivery is Err) return delivery;
    if (renewal is Err) return renewal;
    return exits;
  }

  /// Moves started exits forward, then claims the finished ones, within what
  /// the user authorized when starting them. Foreground only.
  Future<Result<void, ArkFailure>> runExits(ArkAccountId account) async {
    final progress = await ProgressArkExitsUsecase(
      _repository,
      budget,
      topUp: _exitTopUp,
      funding: _exitFunding,
    ).execute(account);
    final claims = await ClaimArkExitsUsecase(
      _repository,
      budget,
    ).execute(account);
    if (progress case Err(:final failure)) return Err(failure);
    return switch (claims) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }

  /// [renewal] is false in the headless task: it reads no seed, so only saved
  /// claims run there and renewal waits for the foreground.
  BackgroundTaskHandler backgroundHandler({bool renewal = true}) =>
      arkRenewalHandler(
        usecase: RunArkBackgroundTaskUsecase(
          accounts,
          budget,
          RunArkSavedClaimsUsecase(_repository, budget),
          _renew,
          renewalEnabled: renewal,
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
