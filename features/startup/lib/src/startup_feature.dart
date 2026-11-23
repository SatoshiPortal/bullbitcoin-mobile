import 'package:access/access.dart';
import 'package:bull_logs/bull_logs.dart' show LogsFacade;
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences/preferences.dart';
import 'package:provisioning/provisioning.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:swaps/swaps.dart';

import 'domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'domain/usecases/get_startup_pin_status_usecase.dart';
import 'domain/usecases/initialize_required_tor_usecase.dart';
import 'domain/usecases/prepare_wallet_startup_usecase.dart';
import 'domain/usecases/restore_missing_default_secret_usecase.dart';
import 'presentation/bloc/app_startup_bloc.dart';
import 'ui/app_startup_widget.dart';

final class StartupFeature {
  final AppStartupBloc Function() _createBloc;

  const StartupFeature._(this._createBloc);

  static StartupFeature mount({
    required Preferences preferences,
    required Secrets secrets,
    required SecretsInventory inventory,
    required DefaultWalletRepair repair,
    required MainnetBackupLookup backupLookup,
    required Tor tor,
    required SwapStartup swapStartup,
  }) => StartupFeature._(
    () => AppStartupBloc(
      prepareWalletStartup: PrepareWalletStartupUsecase(
        const GetStartupPinStatusUsecase(Access()),
        CheckForExistingDefaultWalletsUsecase(
          preferences: preferences,
          inventory: inventory,
          hasWallets: inventory.hasWallets,
          secrets: secrets,
          repair: repair,
        ),
        swapStartup,
        InitializeRequiredTorUsecase(
          backupLookup.hasEncryptedBackup,
          preferences,
          tor,
        ),
      ),
      restoreMissingDefaultSecretUsecase: RestoreMissingDefaultSecretUsecase(
        secrets: secrets,
        recoveryWallets: inventory.recoveryWallets,
      ),
    ),
  );

  Widget scope({
    required Widget child,
    required void Function(BuildContext context) onWalletsReady,
  }) => BlocProvider(
    create: (_) => _createBloc()..add(const AppStartupStarted()),
    child: BlocListener<AppStartupBloc, AppStartupState>(
      listenWhen: (previous, current) =>
          previous != current &&
          current is AppStartupSuccess &&
          current.hasDefaultWallets &&
          !current.isPinCodeSet,
      listener: (context, _) => onWalletsReady(context),
      child: child,
    ),
  );

  Widget gate({
    required Widget app,
    required Widget splash,
    required Future<void> Function() onUnlocked,
    required void Function() openOnboarding,
    required LogsFacade Function() logs,
  }) => AppStartupWidget(
    app: app,
    splash: splash,
    onUnlocked: onUnlocked,
    openOnboarding: openOnboarding,
    logs: logs,
  );

  /// Access calls this only after it has authorized the inventory session.
  void completeUnlock(BuildContext context) =>
      context.read<AppStartupBloc>().add(const AppStartupUnlocked());
}
