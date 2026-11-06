import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, NetworkCapabilities, NetworkCapability, NetworkEnv;
import 'dart:async';

import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/models/auto_swap_model.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/features/autoswap/domain/repositories/auto_swap_settings_repository.dart';
import 'package:drift/drift.dart';

class AutoSwapSettingsRepositoryImpl implements AutoSwapSettingsRepository {
  final SqliteDatabase _database;
  final SettingsRepository _settingsRepository;
  final StreamController<AutoSwap> _controller =
      StreamController<AutoSwap>.broadcast();

  AutoSwapSettingsRepositoryImpl(this._database, this._settingsRepository);

  @override
  Future<AutoSwap> getAutoSwapParams() async {
    final id = await _environmentRowId();
    final row = await (_database.select(
      _database.autoSwap,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null
        ? const AutoSwap()
        : AutoSwapModel.fromSqlite(row).toEntity();
  }

  @override
  Future<void> updateAutoSwapParams(AutoSwap params) async {
    final id = await _environmentRowId();
    final model = AutoSwapModel.fromEntity(params);
    await _database
        .into(_database.autoSwap)
        .insertOnConflictUpdate(
          AutoSwapCompanion.insert(
            id: Value(id),
            enabled: Value(model.enabled),
            balanceThresholdSats: model.balanceThresholdSats,
            triggerBalanceSats: model.triggerBalanceSats,
            feeThresholdPercent: model.feeThresholdPercent,
            blockTillNextExecution: Value(model.blockTillNextExecution),
            alwaysBlock: Value(model.alwaysBlock),
            recipientWalletId: Value(model.recipientWalletId),
            showWarning: Value(model.showWarning),
          ),
        );
    _controller.add(params);
  }

  @override
  Stream<AutoSwap> watchAutoSwapParams() => _controller.stream;

  Future<int> _environmentRowId() async {
    final environment =
        (await _settingsRepository.fetch()).environment.networkEnv;
    final network = switch (environment) {
      NetworkEnv.mainnet => BitcoinNetwork.mainnet,
      NetworkEnv.testnet => BitcoinNetwork.testnet,
      NetworkEnv.regtest => BitcoinNetwork.regtest,
      NetworkEnv.signet => BitcoinNetwork.signet,
    };
    if (!NetworkCapabilities.supports(network, NetworkCapability.swaps)) {
      log.config('Autoswap capability unavailable network=${environment.name}');
      throw const AutoswapNetworkUnavailableException();
    }
    return switch (environment) {
      NetworkEnv.mainnet => 1,
      NetworkEnv.testnet => 2,
      NetworkEnv.regtest ||
      NetworkEnv.signet => throw const AutoswapNetworkUnavailableException(),
    };
  }
}
