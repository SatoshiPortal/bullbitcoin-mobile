import 'package:drift/drift.dart';
import 'package:preferences/preferences.dart' show Preferences;
import 'package:primitives/primitives.dart' show NetworkEnv;

import '../domain/auto_swap_settings_repository.dart';
import '../domain/entities/auto_swap.dart';
import '../domain/entities/swap_failure.dart';
import '../domain/swap_server_control.dart' show readSwapEnvironment;
import 'db/boltz_swaps_database.dart'
    show AutoSwapCompanion, BoltzSwapsDatabase;

class AutoSwapSettingsRepositoryImpl implements AutoSwapSettingsRepository {
  final BoltzSwapsDatabase _database;
  final Preferences _settingsRepository;

  AutoSwapSettingsRepositoryImpl(this._database, this._settingsRepository);

  @override
  Future<AutoSwap> getAutoSwapParams() async {
    final id = await _environmentRowId();
    final row = await (_database.select(
      _database.autoSwap,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null
        ? const AutoSwap()
        : AutoSwap(
            enabled: row.enabled,
            balanceThresholdSats: row.balanceThresholdSats,
            triggerBalanceSats: row.triggerBalanceSats,
            feeThresholdPercent: row.feeThresholdPercent,
            blockTillNextExecution: row.blockTillNextExecution,
            alwaysBlock: row.alwaysBlock,
            recipientWalletId: row.recipientWalletId,
            showWarning: row.showWarning,
          );
  }

  @override
  Future<void> updateAutoSwapParams(AutoSwap params) async {
    final id = await _environmentRowId();
    await _database
        .into(_database.autoSwap)
        .insertOnConflictUpdate(
          AutoSwapCompanion.insert(
            id: Value(id),
            enabled: Value(params.enabled),
            balanceThresholdSats: params.balanceThresholdSats,
            triggerBalanceSats: params.triggerBalanceSats,
            feeThresholdPercent: params.feeThresholdPercent,
            blockTillNextExecution: Value(params.blockTillNextExecution),
            alwaysBlock: Value(params.alwaysBlock),
            recipientWalletId: Value(params.recipientWalletId),
            showWarning: Value(params.showWarning),
          ),
        );
  }

  Future<int> _environmentRowId() async {
    final environment = await readSwapEnvironment(_settingsRepository);
    return switch (environment) {
      NetworkEnv.mainnet => 1,
      NetworkEnv.testnet => 2,
      NetworkEnv.regtest ||
      NetworkEnv.signet => throw const SwapsUnsupportedNetworkFailure(),
    };
  }
}
