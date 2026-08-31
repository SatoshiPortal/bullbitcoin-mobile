import '../domain/entities/vault_context.dart';
import '../domain/entities/vault_completion.dart';
import 'package:secrets/secrets.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../generated/l10n/recoverbull_localizations.dart';
import '../domain/entities/encrypted_vault.dart' as domain;
import '../domain/entities/recoverbull_flow.dart';
import '../domain/recoverbull_environment_port.dart';
import '../domain/recoverbull_legacy_settings_port.dart';
import '../domain/recoverbull_route_port.dart';
import '../ui/screens/vault_flow_page.dart';
import '../ui/widgets/backup_alarm_overlay.dart';
import 'recoverbull_runtime.dart';

import '../data/secrets_vault_repository.dart';
import '../domain/recoverbull_wallet_port.dart';
import '../domain/usecases/create_vault_usecase.dart';
import '../domain/usecases/restore_vault_usecase.dart';
import '../domain/usecases/test_vault_usecase.dart';
import 'recoverbull_facade.dart';

/// Composition stays separate from the feature's business interface.
final class RecoverBullFeature {
  final RecoverBullFacade facade;
  final RecoverBullRuntime? _runtime;

  const RecoverBullFeature._(this.facade, [this._runtime]);

  static const localizationsDelegates =
      RecoverBullLocalizations.localizationsDelegates;

  static Future<RecoverBullFeature> mount({
    required String databasePath,
    required Secrets secrets,
    required RecoverBullWalletPort wallets,
    required RecoverBullEnvironmentPort environment,
    required RecoverBullLegacySettingsPort legacy,
    required RecoverBullRoutePort routes,
    required TorHttpClientFactory clients,
  }) async {
    final runtime = await RecoverBullRuntime.open(
      databasePath: databasePath,
      secrets: secrets,
      wallets: wallets,
      environment: environment,
      legacy: legacy,
      routes: routes,
      clients: clients,
    );
    final vaults = SecretsVaultRepository(secrets);
    return RecoverBullFeature._(
      RecoverBullFacade(
        CreateVaultUsecase(vaults, wallets),
        TestVaultUsecase(vaults, wallets),
        RestoreVaultUsecase(vaults, wallets),
        runtime.readStatus,
        runtime.coldStart,
        runtime.checkServer,
        runtime.parseVault,
        runtime.settings,
        runtime.recoverServerVault,
      ),
      runtime,
    );
  }

  GoRoute route({
    required String Function(BuildContext) copiedMessage,
    required void Function(BuildContext) onRecovered,
  }) => GoRoute(
    path: '/recoverbull-flows',
    name: 'recoverbullFlows',
    builder: (context, state) {
      final runtime = _runtime;
      if (runtime == null) throw StateError('RecoverBull has not been mounted');
      final request = state.extra;
      final flow = request is RecoverBullFlowRequest
          ? request.flow
          : RecoverBullFlow.settings;
      return VaultFlowPage(
        flow: flow,
        presentation: () => runtime.flow(
          flow,
          vault: request is RecoverBullFlowRequest ? request.vault : null,
          backupContext: request is RecoverBullFlowRequest
              ? request.backupContext
              : null,
        ),
        returnCompletion:
            request is RecoverBullFlowRequest && request.returnCompletion,
        copiedMessage: copiedMessage(context),
        onRecovered: () => onRecovered(context),
      );
    },
  );

  Future<T?> open<T>(
    BuildContext context,
    RecoverBullFlow flow, {
    domain.EncryptedVault? vault,
  }) => context.pushNamed<T>(
    'recoverbullFlows',
    extra: RecoverBullFlowRequest(flow, vault),
  );

  /// Creates and tests a backup for the selected seed before returning.
  Future<bool> openSetup(
    BuildContext context, {
    required VaultContext backupContext,
  }) async {
    final created = await context.pushNamed<VaultCompletion>(
      'recoverbullFlows',
      extra: RecoverBullFlowRequest(
        RecoverBullFlow.secureVault,
        null,
        backupContext: backupContext,
        returnCompletion: true,
      ),
    );
    if (created == null || !context.mounted) return false;
    final tested = await context.pushNamed<VaultCompletion>(
      'recoverbullFlows',
      extra: RecoverBullFlowRequest(
        RecoverBullFlow.testVault,
        created.vault,
        backupContext: backupContext,
        returnCompletion: true,
      ),
    );
    return tested?.verifiedContext?.matches(backupContext) == true &&
        tested?.warning == null;
  }

  Future<void> dispose() async => _runtime?.dispose();

  Widget withAlerts(Widget child, {required VoidCallback onOpen}) =>
      BackupAlarmOverlay(
        child: child,
        create: () => _runtime?.monitoringPresenter(),
        onOpen: (_) => onOpen(),
      );

  factory RecoverBullFeature.create({
    required Secrets secrets,
    required RecoverBullWalletPort wallets,
  }) {
    final vaults = SecretsVaultRepository(secrets);
    return RecoverBullFeature._(
      RecoverBullFacade(
        CreateVaultUsecase(vaults, wallets),
        TestVaultUsecase(vaults, wallets),
        RestoreVaultUsecase(vaults, wallets),
      ),
    );
  }
}

final class RecoverBullFlowRequest {
  final RecoverBullFlow flow;
  final domain.EncryptedVault? vault;
  final VaultContext? backupContext;
  final bool returnCompletion;
  const RecoverBullFlowRequest(
    this.flow,
    this.vault, {
    this.backupContext,
    this.returnCompletion = false,
  });
}
