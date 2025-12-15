import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:bb_mobile/core/primitives/network/network.dart';
import 'package:bb_mobile/core/primitives/network/network_environment.dart';
import 'package:bb_mobile/core/primitives/transaction/transaction_direction.dart';
import 'package:bb_mobile/features/wallets/application/errors/wallet_errors.dart';
import 'package:bb_mobile/features/wallets/application/ports/wallet_port.dart';
import 'package:bb_mobile/features/wallets/domain/entities/wallet_transaction_entity.dart';
import 'package:bb_mobile/features/wallets/domain/value_objects/unspent_output_vo.dart';
import 'package:bb_mobile/features/wallets/domain/value_objects/wallet_balance_vo.dart';
import 'package:bb_mobile/features/wallets/frameworks/lwk/lwk_wallet_factory.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lwk/lwk.dart' as lwk;

class LwkWalletAdapter implements WalletPort {
  final SqliteDatabase _database;
  final LwkWalletFactory _lwkWalletFactory;
  final FlutterSecureStorage _secureStorage;

  LwkWalletAdapter({
    required SqliteDatabase database,
    required LwkWalletFactory lwkWalletFactory,
    required FlutterSecureStorage secureStorage,
  }) : _database = database,
       _lwkWalletFactory = lwkWalletFactory,
       _secureStorage = secureStorage;

  @override
  Future<WalletBalanceVo> getBalance(int walletId) async {
    final config = await _getWalletConfigById(walletId);
    final wallet = await _lwkWalletFactory.createWallet(
      id: walletId,
      networkEnvironment: config.networkEnvironment,
      ctDescriptor: config.externalPublicDescriptor,
    );

    final balances = await wallet.balances();
    final assetId = _lBtcAssetId(config.networkEnvironment);

    final lBtcAssetBalance = balances.firstWhere((balance) {
      return balance.assetId == assetId;
    }).value;

    return LiquidWalletBalanceVo(confirmedSat: lBtcAssetBalance);
  }

  @override
  Future<List<WalletTransactionEntity>> getTransactions(int walletId) async {
    final config = await _getWalletConfigById(walletId);
    final wallet = await _lwkWalletFactory.createWallet(
      id: walletId,
      networkEnvironment: config.networkEnvironment,
      ctDescriptor: config.externalPublicDescriptor,
    );

    final assetId = _lBtcAssetId(config.networkEnvironment);

    final transactionSnapshots = await wallet.txs();
    final transactions = transactionSnapshots.map((snapshot) {
      final isIncoming = snapshot.kind == 'incoming';
      final balances = snapshot.balances;
      final finalBalance =
          balances
              .where((e) => e.assetId == assetId)
              .map((e) => e.value)
              .firstOrNull ??
          0;
      final isToSelf =
          snapshot.kind == 'redeposit' ||
          finalBalance.abs() == snapshot.fee.toInt();
      final amountSat = isToSelf
          ? 0
          : isIncoming
          ? finalBalance
          : finalBalance.abs() - snapshot.fee.toInt();

      return WalletTransactionEntity.fromSnapshot(
        txId: snapshot.txid,
        walletId: walletId,
        network: Network.liquid,
        direction: isToSelf
            ? TransactionDirection.self
            : (isIncoming
                  ? TransactionDirection.incoming
                  : TransactionDirection.outgoing),
        amountSat: amountSat,
        feeSat: snapshot.fee.toInt(),
        confirmationTime: snapshot.timestamp == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(snapshot.timestamp! * 1000),
      );
    }).toList();

    return transactions;
  }

  @override
  Future<List<UnspentOutputVO>> getUnspentOutputs(int walletId) async {
    final config = await _getWalletConfigById(walletId);
    final wallet = await _lwkWalletFactory.createWallet(
      id: walletId,
      networkEnvironment: config.networkEnvironment,
      ctDescriptor: config.externalPublicDescriptor,
    );

    final utxos = await wallet.utxos();

    final unspentOutputs = utxos.map((utxo) {
      return UnspentOutputVO(
        txId: utxo.outpoint.txid,
        vout: utxo.outpoint.vout,
        amountSat: utxo.unblinded.value.toInt(),
      );
    }).toList();

    return unspentOutputs;
  }

  Future<LiquidWalletConfigRow> _getWalletConfigById(int walletId) async {
    final walletConfig = await _database.managers.liquidWalletConfigs
        .filter((f) => f.walletId.id(walletId))
        .getSingleOrNull();

    if (walletConfig == null) {
      throw WalletNotFoundError(walletId: walletId);
    }

    return walletConfig;
  }

  String _lBtcAssetId(LiquidNetworkEnvironment networkEnvironment) {
    return networkEnvironment == LiquidNetworkEnvironment.testnet
        ? lwk.lTestAssetId
        : lwk.lBtcAssetId;
  }
}
