import 'dart:async';

import 'package:background_tasks/background_tasks.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:wizard/src/data/datasource/wizard_local_datasource.dart';
import 'package:wizard/src/data/repository/wizard_repository_impl.dart';
import 'package:wizard/src/domain/repository/wizard_repository.dart';
import 'package:wizard/src/domain/usecase/apply_pending_wizard_choices_usecase.dart';
import 'package:wizard/src/domain/usecase/is_wizard_complete_usecase.dart';
import 'package:wizard/src/domain/usecase/read_pending_wizard_choices_usecase.dart';
import 'package:wizard/src/domain/wizard_failure.dart';
import 'package:wizard/src/ui/wizard_app.dart';
import 'package:wizard/src/ui/wizard_branding.dart';

/// Collects choices before app initialization and applies them once their
/// owning capabilities are available. Mounting does not touch storage.
final class WizardFeature {
  final WizardRepository _repository;

  WizardFeature.mount()
    : _repository = WizardRepositoryImpl(WizardLocalDatasourceImpl());

  /// Shows the standalone wizard before migrations or networking can run.
  Future<Result<void, WizardFailure>> runIfNeeded({
    required String notificationChannelId,
    required bool exchangeAllowed,
    required WizardBranding branding,
  }) async {
    try {
      if (await IsWizardCompleteUsecase(repository: _repository).execute()) {
        return const Ok(null);
      }
    } on Exception {
      log.warning('Wizard could not read its completion marker');
      return const Err(WizardStorageFailure());
    }
    final completer = Completer<void>();
    runApp(
      WizardApp(
        notificationChannelId: notificationChannelId,
        exchangeAllowed: exchangeAllowed,
        branding: branding,
        onDone: (_) => completer.complete(),
      ),
    );
    await completer.future;
    return const Ok(null);
  }

  /// Returns null when the user has not staged a choice, and false when
  /// the user explicitly declined reporting.
  Future<Result<bool?, WizardFailure>> readReportingConsent() async {
    try {
      final pending = await ReadPendingWizardChoicesUsecase(
        repository: _repository,
      ).execute();
      return Ok(pending?.reportingConsent);
    } on Exception {
      log.warning('Wizard could not read pending reporting consent');
      return const Err(WizardStorageFailure());
    }
  }

  /// Applies only touched choices; writes that fail stay pending for retry.
  Future<Result<void, WizardFailure>> applyPendingChoices({
    required Preferences preferences,
    required Exchange exchange,
  }) async {
    try {
      await ApplyPendingWizardChoicesUsecase(
        wizardRepository: _repository,
        settingsRepository: preferences,
        intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
        applyExchangeAccess: exchange.applyInitialChoice,
      ).execute();
      return const Ok(null);
    } on Exception {
      log.warning('Wizard could not apply its pending choices');
      return const Err(WizardStorageFailure());
    }
  }
}
