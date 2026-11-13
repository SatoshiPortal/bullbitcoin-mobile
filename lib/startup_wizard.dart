import 'dart:async';

import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/data/repository/wizard_repository_impl.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/is_wizard_complete_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/read_pending_wizard_choices_usecase.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_app.dart';
import 'package:flutter/widgets.dart';

WizardRepository _buildPreInitWizardRepository() =>
    WizardRepositoryImpl(WizardLocalDatasourceImpl());

/// Collects consent before migrations or network initialization can run.
Future<void> runStartupWizard() async {
  final repository = _buildPreInitWizardRepository();
  final isComplete = await IsWizardCompleteUsecase(
    repository: repository,
  ).execute();
  if (!isComplete) {
    final completer = Completer<void>();
    runApp(WizardApp(onDone: (_) => completer.complete()));
    await completer.future;
  }
}

Future<bool?> readStartupReportingConsent() async {
  final pending = await ReadPendingWizardChoicesUsecase(
    repository: _buildPreInitWizardRepository(),
  ).execute();
  return pending?.reportingConsent;
}
