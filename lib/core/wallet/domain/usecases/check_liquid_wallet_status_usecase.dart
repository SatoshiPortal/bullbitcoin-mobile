import 'dart:io';
import 'dart:math';

import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:lwk/lwk.dart' as lwk;
import 'package:path_provider/path_provider.dart';

class TheDirtyLiquidUsecase {
  TheDirtyLiquidUsecase(
    this._settingsRepository,
    this._electrumServerRepository,
  );
  final SettingsRepository _settingsRepository;
  final ElectrumServerRepository _electrumServerRepository;

  Future<({BigInt satoshis, int transactions})> call(
    bip39.Mnemonic mnemonic,
  ) async {
    final random = Random();
    final dbName = 'tmp_${random.nextInt(999999)}';
    String? dbPath;

    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final network = Network.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: true,
      );

      final lwkNetwork =
          environment.isTestnet ? lwk.Network.testnet : lwk.Network.mainnet;

      final descriptor = await lwk.Descriptor.newConfidential(
        mnemonic: mnemonic.words.join(' '),
        network: lwkNetwork,
      );

      dbPath = await _getDbPath(dbName);

      final wallet = await lwk.Wallet.init(
        network: lwkNetwork,
        dbpath: dbPath,
        descriptor: descriptor,
      );

      final electrumServer = await _electrumServerRepository
          .getPrioritizedServer(network: network);

      final electrumServerModel = ElectrumServerModel.fromEntity(
        electrumServer,
      );

      await wallet.sync_(
        electrumUrl: electrumServerModel.url,
        validateDomain: electrumServerModel.validateDomain,
      );

      final balances = await wallet.balances();
      final transactions = await wallet.txs();

      final lBtcAssetBalance =
          balances.firstWhere((balance) {
            final assetId = _lBtcAssetId(network);
            return balance.assetId == assetId;
          }).value;

      return (
        satoshis: BigInt.from(lBtcAssetBalance),
        transactions: transactions.length,
      );
    } catch (e) {
      log.severe(e);
      throw CheckLiquidWalletStatusException(e.toString());
    } finally {
      if (dbPath != null) {
        await _cleanupDbPath(dbPath);
      }
    }
  }

  Future<String> _getDbPath(String dbName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/$dbName';
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  Future<void> _cleanupDbPath(String dbPath) async {
    try {
      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      log.warning('Failed to cleanup database file: $dbPath - $e');
    }
  }

  String _lBtcAssetId(Network network) {
    switch (network) {
      case Network.liquidMainnet:
        return '6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d';
      case Network.liquidTestnet:
        return '144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49';
      default:
        throw UnsupportedLwkNetworkException(
          'Bitcoin network is not supported by LWK',
        );
    }
  }
}

class CheckLiquidWalletStatusException implements Exception {
  final String message;

  CheckLiquidWalletStatusException(this.message);

  @override
  String toString() => message;
}

class UnsupportedLwkNetworkException implements Exception {
  final String message;

  UnsupportedLwkNetworkException(this.message);

  @override
  String toString() => message;
}
