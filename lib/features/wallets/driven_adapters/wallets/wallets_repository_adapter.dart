import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:bb_mobile/core/primitives/network/network.dart';
import 'package:bb_mobile/core/primitives/network/network_environment.dart';
import 'package:bb_mobile/features/wallets/application/ports/wallets_repository_port.dart';
import 'package:bb_mobile/features/wallets/domain/entities/wallet_entity.dart';
import 'package:bb_mobile/features/wallets/driven_adapters/wallets/mappers/wallet_mapper.dart';
import 'package:drift/drift.dart';

class WalletsRepositoryAdapter implements WalletsRepositoryPort {
  final SqliteDatabase _database;

  WalletsRepositoryAdapter({required SqliteDatabase database})
    : _database = database;

  @override
  Future<WalletEntity> createWallet({
    String? label,
    required Network network,
    required bool isDefault,
    DateTime? birthday,
  }) async {
    final wallet = await _database
        .into(_database.walletMetadatas)
        .insertReturning(
          WalletMetadatasCompanion.insert(
            label: Value(label),
            isDefault: isDefault,
            network: network,
            birthday: Value(birthday),
          ),
        );

    return WalletMapper.walletMetadataRowToWalletEntity(wallet);
  }

  @override
  Future<List<WalletEntity>> getAllWallets() async {
    final walletRows = await _database.select(_database.walletMetadatas).get();

    return walletRows
        .map(WalletMapper.walletMetadataRowToWalletEntity)
        .toList();
  }

  @override
  Future<List<WalletEntity>> getMainnetWallets() async {
    // Get Bitcoin mainnet wallets
    final bitcoinMainnetQuery =
        _database.select(_database.walletMetadatas).join([
          innerJoin(
            _database.bitcoinWalletConfigs,
            _database.bitcoinWalletConfigs.walletId.equalsExp(
              _database.walletMetadatas.id,
            ),
          ),
        ])..where(
          _database.walletMetadatas.network.equals(Network.bitcoin.name) &
              _database.bitcoinWalletConfigs.networkEnvironment.equals(
                BitcoinNetworkEnvironment.mainnet.name,
              ),
        );

    // Get Liquid mainnet wallets
    final liquidMainnetQuery =
        _database.select(_database.walletMetadatas).join([
          innerJoin(
            _database.liquidWalletConfigs,
            _database.liquidWalletConfigs.walletId.equalsExp(
              _database.walletMetadatas.id,
            ),
          ),
        ])..where(
          _database.walletMetadatas.network.equals(Network.liquid.name) &
              _database.liquidWalletConfigs.networkEnvironment.equals(
                LiquidNetworkEnvironment.mainnet.name,
              ),
        );

    final bitcoinResults = await bitcoinMainnetQuery.get();
    final liquidResults = await liquidMainnetQuery.get();

    final wallets = <WalletEntity>[];

    for (final result in bitcoinResults) {
      wallets.add(
        WalletMapper.walletMetadataRowToWalletEntity(
          result.readTable(_database.walletMetadatas),
        ),
      );
    }

    for (final result in liquidResults) {
      wallets.add(
        WalletMapper.walletMetadataRowToWalletEntity(
          result.readTable(_database.walletMetadatas),
        ),
      );
    }

    return wallets;
  }

  @override
  Future<List<WalletEntity>> getTestnetWallets() async {
    // Get Bitcoin testnet wallets
    final bitcoinTestnetQuery =
        _database.select(_database.walletMetadatas).join([
          innerJoin(
            _database.bitcoinWalletConfigs,
            _database.bitcoinWalletConfigs.walletId.equalsExp(
              _database.walletMetadatas.id,
            ),
          ),
        ])..where(
          _database.walletMetadatas.network.equals(Network.bitcoin.name) &
              _database.bitcoinWalletConfigs.networkEnvironment.equals(
                BitcoinNetworkEnvironment.testnet3.name,
              ),
        );

    // Get Liquid testnet wallets
    final liquidTestnetQuery =
        _database.select(_database.walletMetadatas).join([
          innerJoin(
            _database.liquidWalletConfigs,
            _database.liquidWalletConfigs.walletId.equalsExp(
              _database.walletMetadatas.id,
            ),
          ),
        ])..where(
          _database.walletMetadatas.network.equals(Network.liquid.name) &
              _database.liquidWalletConfigs.networkEnvironment.equals(
                LiquidNetworkEnvironment.testnet.name,
              ),
        );

    final bitcoinResults = await bitcoinTestnetQuery.get();
    final liquidResults = await liquidTestnetQuery.get();

    final wallets = <WalletEntity>[];

    for (final result in bitcoinResults) {
      wallets.add(
        WalletMapper.walletMetadataRowToWalletEntity(
          result.readTable(_database.walletMetadatas),
        ),
      );
    }

    for (final result in liquidResults) {
      wallets.add(
        WalletMapper.walletMetadataRowToWalletEntity(
          result.readTable(_database.walletMetadatas),
        ),
      );
    }

    return wallets;
  }

  @override
  Future<WalletEntity> getWalletById(int walletId) async {
    final walletRow = await (_database.select(
      _database.walletMetadatas,
    )..where((tbl) => tbl.id.equals(walletId))).getSingle();

    return WalletMapper.walletMetadataRowToWalletEntity(walletRow);
  }
}
