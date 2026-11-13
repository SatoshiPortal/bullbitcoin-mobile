import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wizard/public/wizard_startup_facade.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_app.dart';
import 'package:flutter/widgets.dart';

/// Collects consent before migrations or network initialization can run.
Future<void> runStartupWizard() async {
  final result = await WizardStartupFacade().shouldRunWizard();
  switch (result) {
    case Err(:final failure):
      throw WizardStartupException(failure);
    case Ok(value: false):
      return;
    case Ok(value: true):
      final completer = Completer<void>();
      runApp(WizardApp(onDone: (_) => completer.complete()));
      await completer.future;
  }
}

Future<bool?> readStartupReportingConsent() =>
    WizardStartupFacade().readReportingConsent();
