import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:bb_mobile/core/primitives/network/network.dart';
import 'package:bb_mobile/core/primitives/transaction/transaction_direction.dart';
import 'package:bb_mobile/features/wallets/application/errors/wallet_errors.dart';
import 'package:bb_mobile/features/wallets/application/ports/wallet_port.dart';
import 'package:bb_mobile/features/wallets/domain/entities/wallet_transaction_entity.dart';
import 'package:bb_mobile/features/wallets/domain/value_objects/wallet_output_vo.dart';
import 'package:bb_mobile/features/wallets/domain/value_objects/wallet_balance_vo.dart';
import 'package:bb_mobile/features/wallets/frameworks/bdk/bdk_wallet_factory.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BdkWalletAdapter implements WalletPort {
  final SqliteDatabase _database;
  final BdkWalletFactory _bdkWalletFactory;
  final FlutterSecureStorage _secureStorage;

  BdkWalletAdapter({
    required SqliteDatabase database,
    required BdkWalletFactory bdkWalletFactory,
    required FlutterSecureStorage secureStorage,
  }) : _database = database,
       _bdkWalletFactory = bdkWalletFactory,
       _secureStorage = secureStorage;

  @override
  Future<WalletBalanceVO> getBalance(int walletId) async {
    final wallet = await _getWalletById(walletId);

    final balance = wallet.getBalance();

    return BitcoinWalletBalanceVO(
      immatureSat: balance.immature.toInt(),
      trustedPendingSat: balance.trustedPending.toInt(),
      untrustedPendingSat: balance.untrustedPending.toInt(),
      confirmedSat: balance.confirmed.toInt(),
    );
  }

  @override
  Future<List<WalletTransactionEntity>> getTransactions(int walletId) async {
    final wallet = await _getWalletById(walletId);

    final transactionSnapshots = wallet.listTransactions(includeRaw: true);
    final transactions = transactionSnapshots.map((snapshot) {
      final receivedAmountSat = snapshot.received.toInt();
      final sentAmountSat = snapshot.sent.toInt();
      final utxos = snapshot.transaction!.output();
      final isToSelf = utxos.every((output) {
        final belongsToUs = wallet.isMine(script: output.scriptPubkey);
        if (belongsToUs) {
          return true;
        }
        return false;
      });
      final direction = isToSelf
          ? TransactionDirection.self
          : (receivedAmountSat > sentAmountSat
                ? TransactionDirection.incoming
                : TransactionDirection.outgoing);
      final amountSat = isToSelf
          ? 0
          : direction == TransactionDirection.incoming
          ? (receivedAmountSat - sentAmountSat)
          : (sentAmountSat - receivedAmountSat);
      final feeSat = snapshot.fee?.toInt() ?? 0;
      final confirmationTime = snapshot.confirmationTime == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (snapshot.confirmationTime!.timestamp * BigInt.from(1000))
                  .toInt(),
            );

      return WalletTransactionEntity.fromSnapshot(
        txId: snapshot.txid,
        walletId: walletId,
        network: Network.bitcoin,
        direction: direction,
        amountSat: amountSat,
        feeSat: feeSat,
        confirmationTime: confirmationTime,
      );
    }).toList();

    return transactions;
  }

  @override
  Future<List<WalletOutputVO>> getUnspentOutputs(int walletId) async {
    final wallet = await _getWalletById(walletId);

    final unspentList = wallet.listUnspent();
    final unspentOutputs = unspentList.map((unspent) {
      return WalletOutputVO(
        txId: unspent.outpoint.txid,
        vout: unspent.outpoint.vout,
        amountSat: unspent.txout.value.toInt(),
        isChangeOutput: unspent.keychain == bdk.KeychainKind.internalChain,
      );
    }).toList();

    return unspentOutputs;
  }

  Future<bdk.Wallet> _getWalletById(int walletId) async {
    final walletConfig = await _database.managers.bitcoinWalletConfigs
        .filter((f) => f.walletId.id(walletId))
        .getSingleOrNull();

    if (walletConfig == null) {
      throw WalletNotFoundError(walletId: walletId);
    }

    final wallet = await _bdkWalletFactory.createWallet(
      id: walletId,
      networkEnvironment: walletConfig.networkEnvironment,
      externalPublicDescriptor: walletConfig.externalPublicDescriptor,
      internalPublicDescriptor: walletConfig.internalPublicDescriptor,
    );

    return wallet;
  }
}
