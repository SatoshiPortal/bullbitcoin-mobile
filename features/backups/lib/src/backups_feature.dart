import 'package:access/access.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
import 'package:bull_recoverbull/storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import '../generated/l10n/backups_localizations.dart';
import 'backups_copy.dart';
import 'backups_l10n.dart';
import 'domain/backup_records.dart';
import 'domain/read_backup_status_usecase.dart';
import 'domain/usecases/complete_backup_verification_usecase.dart';
import 'domain/usecases/get_secret_from_fingerprint_usecase.dart';
import 'domain/usecases/load_wallets_for_network_usecase.dart';
import 'flow.dart';
import 'presentation/bloc/test_wallet_backup_bloc.dart';
import 'presentation/cubit/backup_settings_cubit.dart';
import 'ui/backup_options_screen.dart';
import 'ui/screens/backup_settings_screen.dart';

const _statusRoute = 'backupSettings';
const _optionsRoute = 'backupOptions';
const _physicalRoute = 'testPhysicalBackupFlow';
const _dataBackupRoute = 'dataBackup';

enum _BackupIntent { start, verify }

final class BackupsFeature {
  final GoRoute route;

  const BackupsFeature._(this.route);

  static const localizationsDelegate = BackupsLocalizations.delegate;

  /// Unknown readiness lets the host retain its existing fallback.
  static Future<bool?> readWarningNeeded(
    Future<Result<bool, rb.RecoverBullFailure>> Function() read,
  ) async => switch (await read()) {
    Ok(:final value) => value,
    Err() => null,
  };

  static BackupsFeature mount({
    required Secrets Function() secrets,
    required WalletInventory Function() inventory,
    required ActiveEnvironmentReader Function() environment,
    required RecoverBullWalletBackups Function(Network network) records,
    required Future<Result<rb.BackupStatus, rb.RecoverBullFailure>> Function(
      rb.VaultContext,
    )
    vaultStatus,
    required Widget encryptedIcon,
    required Widget physicalIcon,
    required ImageProvider successImage,
    required void Function(BuildContext) onTestSucceeded,
    required void Function(BuildContext) onExportTransactions,
    Access access = const Access(),
    Widget Function(BuildContext)? dataBackup,
    String Function(BuildContext)? dataBackupStatus,
    Listenable? dataBackupChanges,
  }) {
    return BackupsFeature._(
      GoRoute(
        name: _statusRoute,
        path: 'backup-settings',
        builder: (context, _) => BlocProvider(
          create: (_) => BackupSettingsCubit(
            ReadBackupStatusUsecase(
              inventory(),
              environment(),
              (network, fingerprint) =>
                  records(network).projection(fingerprint),
              vaultStatus,
            ),
          )..checkBackupStatus(),
          child: BackupSettingsScreen(
            onExportTransactions: () => onExportTransactions(context),
            onOpenAutomaticBackup: dataBackup == null
                ? null
                : () => context.pushNamed(_dataBackupRoute),
            automaticBackupStatus: dataBackupStatus,
            automaticBackupChanges: dataBackupChanges,
          ),
        ),
        routes: [
          if (dataBackup != null)
            GoRoute(
              name: _dataBackupRoute,
              path: 'data-backup',
              builder: (context, _) => dataBackup(context),
            ),
          backupOptionsRoute(
            copyOf: _copyOf,
            encryptedIcon: encryptedIcon,
            physicalIcon: physicalIcon,
            onStartPhysical: (context) =>
                BackupsNavigation.openPhysical(context),
            onVerifyPhysical: (context) =>
                BackupsNavigation.openPhysical(context, verify: true),
          ),
          GoRoute(
            name: _physicalRoute,
            path: '/test-physical-backup-flow',
            builder: (context, state) => BlocProvider(
              create: (_) => createBackupBloc(
                secrets(),
                inventory(),
                environment(),
                records,
              )..add(const LoadWallets()),
              child: TestPhysicalBackupFlowNavigator(
                flow: state.extra == TestPhysicalBackupFlow.verify
                    ? TestPhysicalBackupFlow.verify
                    : TestPhysicalBackupFlow.backup,
                onTestSucceeded: onTestSucceeded,
                successImage: successImage,
                access: access,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

TestWalletBackupBloc createBackupBloc(
  Secrets secrets,
  WalletInventory inventory,
  ActiveEnvironmentReader environment,
  BackupRecords records,
) => TestWalletBackupBloc(
  loadWalletsForNetworkUsecase: LoadWalletsForNetworkUsecase(
    inventory,
    environment,
    records,
  ),
  getSecretFromFingerprintUsecase: GetSecretFromFingerprintUsecase(
    secrets: secrets,
  ),
  completeBackupVerificationUsecase: CompleteBackupVerificationUsecase(records),
);

GoRoute backupOptionsRoute({
  required BackupsCopy Function(BuildContext) copyOf,
  required Widget encryptedIcon,
  required Widget physicalIcon,
  required void Function(BuildContext) onStartPhysical,
  required void Function(BuildContext) onVerifyPhysical,
}) => GoRoute(
  name: _optionsRoute,
  path: 'backup-options',
  builder: (context, state) {
    final verify = state.extra == _BackupIntent.verify;
    return BackupOptionsScreen(
      copy: copyOf(context),
      verify: verify,
      encryptedIcon: encryptedIcon,
      physicalIcon: physicalIcon,
      onOpenPhysical: verify ? onVerifyPhysical : onStartPhysical,
    );
  },
);

abstract final class BackupsNavigation {
  static Future<void> open(BuildContext context) =>
      context.pushNamed<void>(_statusRoute);

  static Future<void> start(BuildContext context) =>
      context.pushNamed<void>(_optionsRoute, extra: _BackupIntent.start);

  static Future<void> verify(BuildContext context) =>
      context.pushNamed<void>(_optionsRoute, extra: _BackupIntent.verify);

  static Future<void> openPhysical(
    BuildContext context, {
    bool verify = false,
  }) => context.pushNamed<void>(
    _physicalRoute,
    extra: verify
        ? TestPhysicalBackupFlow.verify
        : TestPhysicalBackupFlow.backup,
  );
}

BackupsCopy _copyOf(BuildContext context) {
  final loc = context.loc;
  return (
    backupTitle: loc.backupWalletTitle,
    testTitle: loc.testBackupTitle,
    importanceWarning: loc.backupWalletImportanceWarning,
    encrypted: (
      title: loc.backupWalletEncryptedVaultTitle,
      description: loc.backupWalletEncryptedVaultDescription,
      tag: loc.backupWalletEncryptedVaultTag,
    ),
    physical: (
      title: loc.backupWalletPhysicalBackupTitle,
      description: loc.backupWalletPhysicalBackupDescription,
      tag: loc.backupWalletPhysicalBackupTag,
    ),
    helpLabel: loc.backupWalletHowToDecide,
    helpTitle: loc.backupWalletHowToDecideBackupModalTitle,
    closeLabel: loc.closeDialogButton,
    losePhysical: loc.backupWalletHowToDecideBackupLosePhysical,
    encryptedVault: loc.backupWalletHowToDecideBackupEncryptedVault,
    physicalRecommendation:
        loc.backupWalletHowToDecideBackupPhysicalRecommendation,
    physicalRecommendationText:
        loc.backupWalletHowToDecideBackupPhysicalRecommendationText,
    encryptedRecommendation:
        loc.backupWalletHowToDecideBackupEncryptedRecommendation,
    encryptedRecommendationText:
        loc.backupWalletHowToDecideBackupEncryptedRecommendationText,
    moreInfo: loc.backupWalletHowToDecideBackupMoreInfo,
  );
}
