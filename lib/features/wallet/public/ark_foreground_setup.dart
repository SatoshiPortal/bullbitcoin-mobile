/// Privileged wallet-owned composition. The caller owns the returned runtime.
library;

import 'package:background_tasks/background_tasks.dart';
import 'package:bull_ark/ark_setup.dart' show ArkPreferencesRepository;
import 'package:get_it/get_it.dart';

import '../data/ark_foreground_host.dart';
import '../ui/widgets/ark_payment_scanner.dart';

export '../data/ark_foreground_runtime.dart'
    show
        ArkBoardFundingBinding,
        ArkBoardFundingFactory,
        ArkForegroundRuntime,
        openArkForeground,
        prepareArkCustodyReferences;
export '../data/ark_foreground_host.dart' show ArkForegroundHost, arkHostPaths;

/// Composes wallet-owned UI capabilities without making them root policy.
Future<void> setupArkForeground(
  GetIt locator, {
  required Uri arkUrl,
  required Uri primaryEsploraUrl,
  required bool initializeNew,
  ArkPreferencesRepository? preferences,
  BackgroundTaskDispatcher? dispatcher,
}) => ArkForegroundHost.setup(
  locator,
  arkUrl: arkUrl,
  primaryEsploraUrl: primaryEsploraUrl,
  initializeNew: initializeNew,
  preferences: preferences,
  dispatcher: dispatcher,
  scanner: scanArkPayment,
);
