import 'dart:async';
import 'dart:io';

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

  /// Conservatively hides first-install controls when any prior app storage
  /// is visible. Custody is checked again after its inventory is opened.
  static Future<bool> mayOfferInitialNetwork({
    required Directory documents,
    required Directory support,
  }) async {
    try {
      if (await WizardLocalDatasourceImpl().readCompletedVersion() != null) {
        return false;
      }
      final legacy = Directory(documents.path);
      await for (final entry in legacy.list(followLinks: false)) {
        final name = entry.uri.pathSegments
            .where((part) => part.isNotEmpty)
            .last;
        if ([
          'bullbitcoin_sqlite.sqlite',
          'recoverbull',
          'boltz_swaps',
          'payjoin',
          'ark',
        ].any(name.startsWith)) {
          return false;
        }
      }
      for (final name in ['databases', 'storage-coordination']) {
        final directory = Directory('${support.path}/$name');
        final type = await FileSystemEntity.type(
          directory.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.notFound) continue;
        if (type != FileSystemEntityType.directory) return false;
        await for (final _ in directory.list(followLinks: false)) {
          return false;
        }
      }
      return true;
    } on Exception {
      return false;
    }
  }

  /// Shows the standalone wizard before migrations or networking can run.
  Future<Result<void, WizardFailure>> runIfNeeded({
    required String notificationChannelId,
    required bool exchangeAllowed,
    required WizardBranding branding,
    bool allowDeveloperNetwork = false,
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
        allowDeveloperNetwork: allowDeveloperNetwork,
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

  Future<Result<Environment?, WizardFailure>> readPendingNetwork() async {
    try {
      final pending = await _repository.readPending();
      return Ok(pending?.network);
    } on Exception {
      return const Err(WizardStorageFailure());
    }
  }

  Future<Result<void, WizardFailure>> clearPendingNetwork() async {
    try {
      await _repository.clearPendingNetwork();
      return const Ok(null);
    } on Exception {
      return const Err(WizardStorageFailure());
    }
  }

  /// Applies only touched choices; writes that fail stay pending for retry.
  Future<Result<void, WizardFailure>> applyPendingChoices({
    required Preferences preferences,
    required Exchange exchange,
  }) async {
    try {
      final result = await ApplyPendingWizardChoicesUsecase(
        wizardRepository: _repository,
        settingsRepository: preferences,
        intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
        applyExchangeAccess: exchange.applyInitialChoice,
      ).execute();
      if (result case Err(:final failure)) {
        log.warning(
          'Wizard could not apply screen privacy: ${failure.runtimeType}',
        );
        return const Err(WizardStorageFailure());
      }
      return const Ok(null);
    } on Exception {
      log.warning('Wizard could not apply its pending choices');
      return const Err(WizardStorageFailure());
    }
  }
}
