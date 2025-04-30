import 'dart:async';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_input_pair_model.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_receiver_model_extension.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_sender_model_extension.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart' show PayjoinConstants;
import 'package:bb_mobile/core/utils/transaction_parsing.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet/impl/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:flutter/foundation.dart';
import 'package:payjoin_flutter/uri.dart' show Url;
import 'package:synchronized/synchronized.dart';

class PayjoinRepository {
  final PayjoinDatasource _source;
  final SqliteDatasource _sqlite;
  final SeedDatasource _seed;
  final BdkWalletDatasource _bdkWallet;
  final BdkBitcoinBlockchainDatasource _blockchain;
  final ElectrumServerStorageDatasource _electrumServerStorage;
  // Lock to prevent the same utxo from being used in multiple payjoin proposals
  final Lock _lock;

  PayjoinRepository({
    required PayjoinDatasource payjoinDatasource,
    required SqliteDatasource sqliteDatasource,
    required SeedDatasource seedDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required BdkBitcoinBlockchainDatasource blockchainDatasource,
    required ElectrumServerStorageDatasource electrumServerStorageDatasource,
  }) : _source = payjoinDatasource,
       _sqlite = sqliteDatasource,
       _seed = seedDatasource,
       _bdkWallet = bdkWalletDatasource,
       _blockchain = blockchainDatasource,
       _electrumServerStorage = electrumServerStorageDatasource,
       _lock = Lock();

  Stream<PayjoinReceiver> get requestsForReceivers => _source
      .requestsForReceivers
      .map((payjoinModel) => payjoinModel.toEntity());
  Stream<PayjoinSender> get proposalsForSenders => _source.proposalsForSenders
      .map((payjoinModel) => payjoinModel.toEntity());
  Stream<dynamic> get expiredPayjoins =>
      _source.expiredPayjoins.map((model) => model.toEntity());

  Future<Payjoin?> getPayjoinByTxId(String txId) async {
    final payjoinModels = await _source.fetchAll();

    Payjoin? payjoin;
    try {
      final payjoinModel = payjoinModels.firstWhere(
        (payjoin) => payjoin.txId == txId,
      );
      if (payjoinModel is PayjoinSenderModel) {
        payjoin = payjoinModel.toEntity();
      } else if (payjoinModel is PayjoinReceiverModel) {
        payjoin = payjoinModel.toEntity();
      }
    } catch (e) {
      debugPrint('Payjoin not found for txId: $txId');
    }

    return payjoin;
  }

  Future<bool> checkOhttpRelayHealth() async {
    final directory = await Url.fromStr(PayjoinConstants.directoryUrl);
    final (ohttpKeys, ohttpRelay) = await _source.fetchOhttpKeyAndRelay(
      payjoinDirectory: directory,
    );
    return ohttpKeys != null && ohttpRelay != null;
  }

  // TODO: Remove this and use the general frozen utxo datasource
  Future<List<({String txId, int vout})>>
  getUtxosFrozenByOngoingPayjoins() async {
    final payjoins = await _source.fetchAll(onlyOngoing: true);
    final inputs = await Future.wait(
      payjoins.map((payjoin) async {
        final psbt =
            payjoin is PayjoinReceiverModel
                ? payjoin.proposalPsbt
                : (payjoin as PayjoinSenderModel).originalPsbt;

        if (psbt == null) return null;

        String? walletId;
        if (payjoin is PayjoinSenderModel) {
          walletId = payjoin.walletId;
        } else if (payjoin is PayjoinReceiverModel) {
          walletId = payjoin.walletId;
        }

        WalletMetadataModel? metadata;
        if (walletId != null) {
          metadata =
              await _sqlite.managers.walletMetadatas
                  .filter((f) => f.id(walletId))
                  .getSingleOrNull();
        }

        if (metadata == null) return null;

        // Extract the spent utxos from the proposal psbt
        final spentUtxos = await TransactionParsing.extractSpentUtxosFromPsbt(
          psbt,
          isTestnet: metadata.isTestnet,
        );
        return spentUtxos;
      }),
    );

    return inputs
        .whereType<List<({String txId, int vout})>>()
        .expand((element) => element)
        .toList();
  }

  Future<PayjoinReceiver> createPayjoinReceiver({
    required String walletId,
    required String address,
    required bool isTestnet,
    required BigInt maxFeeRateSatPerVb,
    int? expireAfterSec,
  }) async {
    final model = await _source.createReceiver(
      walletId: walletId,
      address: address,
      isTestnet: isTestnet,
      maxFeeRateSatPerVb: maxFeeRateSatPerVb,
      expireAfterSec: expireAfterSec,
    );

    return model.toEntity();
  }

  Future<PayjoinSender> createPayjoinSender({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  }) async {
    // Create the payjoin sender session
    final model = await _source.createSender(
      walletId: walletId,
      bip21: bip21,
      originalPsbt: originalPsbt,
      networkFeesSatPerVb: networkFeesSatPerVb,
      expireAfterSec: expireAfterSec,
    );

    // Return a payjoin entity with send details
    final payjoin = model.toEntity();

    return payjoin;
  }

  Future<PayjoinReceiver> processRequest({
    required String id,
    required FutureOr<bool> Function(Uint8List) hasOwnedInputs,
    required FutureOr<bool> Function(Uint8List) hasReceiverOutput,
    required List<BitcoinWalletUtxo> unspentUtxos,
    required FutureOr<String> Function(String) processPsbt,
  }) async {
    // A lock is needed here to make sure the proposal of a payjoin is stored
    //  before another payjoin checks for available inputs to create a proposal
    final payjoinReceiver = await _lock.synchronized(() async {
      debugPrint('unspentUtxos: $unspentUtxos');
      // Make sure the inputs to select from for the proposal are not used by
      //  ongoing payjoins already
      final lockedUtxos = await getUtxosFrozenByOngoingPayjoins();
      debugPrint(
        'lockedUtxos: --- ${lockedUtxos.map((input) => '${input.txId}:${input.vout}').join(', ')} ---',
      );

      final pdkInputPairs =
          unspentUtxos
              .where((unspent) {
                final isUtxoLocked = lockedUtxos.any((locked) {
                  return unspent.txId == locked.txId &&
                      unspent.vout == locked.vout;
                });

                return !isUtxoLocked;
              })
              .map((utxo) => PayjoinInputPairModel.fromUtxo(utxo))
              .toList();

      debugPrint(
        'pdkInputPairs: --- ${pdkInputPairs.map((input) => '${input.txId}:${input.vout}').join(', ')} ---',
      );

      if (pdkInputPairs.isEmpty) {
        throw const NoInputsToPayjoinException(
          message: 'No inputs available to create a new payjoin proposal',
        );
      }

      final model = await _source.processRequest(
        id: id,
        hasOwnedInputs: hasOwnedInputs,
        hasReceiverOutput: hasReceiverOutput,
        inputPairs: pdkInputPairs,
        processPsbt: processPsbt,
      );

      return model.toEntity();
    });

    return payjoinReceiver;
  }

  Future<String> signPsbt({
    required String walletId,
    required String psbt,
  }) async {
    final walletMetadata =
        await _sqlite.managers.walletMetadatas
            .filter((e) => e.id(walletId))
            .getSingleOrNull();

    if (walletMetadata == null) {
      throw Exception('Wallet metadata not found');
    }

    final seed =
        await _seed.get(walletMetadata.masterFingerprint) as MnemonicSeed;
    final mnemonic = seed.mnemonicWords.join(' ');

    final wallet =
        WalletModel.privateBdk(
              id: walletId,
              scriptType: ScriptType.fromName(walletMetadata.scriptType),
              mnemonic: mnemonic,
              passphrase: seed.passphrase,
              isTestnet: walletMetadata.isTestnet,
            )
            as PrivateBdkWalletModel;

    final signedPsbt = await _bdkWallet.signPsbt(psbt, wallet: wallet);

    return signedPsbt;
  }

  Future<PayjoinSender> broadcastPsbt({
    required String payjoinId,
    required String finalizedPsbt,
    required Network network,
  }) async {
    // TODO: Should we get all the electrum servers and try another one if the
    //  first one fails?
    final electrumServer =
        await _electrumServerStorage.getDefaultServerByProvider(
          DefaultElectrumServerProvider.blockstream,
          network: network,
        ) ??
        ElectrumServerModel.blockstream(
          isTestnet: network.isTestnet,
          isLiquid: network.isLiquid,
        );

    await _blockchain.broadcastPsbt(
      finalizedPsbt,
      electrumServer: electrumServer,
    );

    final model = await _source.completeSender(payjoinId);

    return model.toEntity();
  }

  Future<PayjoinReceiver> broadcastOriginalTransaction({
    required String payjoinId,
    required Uint8List originalTxBytes,
    required Network network,
  }) async {
    // TODO: Should we get all the electrum servers and try another one if the
    //  first one fails?
    final electrumServer =
        await _electrumServerStorage.getDefaultServerByProvider(
          DefaultElectrumServerProvider.blockstream,
          network: network,
        ) ??
        ElectrumServerModel.blockstream(
          isTestnet: network.isTestnet,
          isLiquid: network.isLiquid,
        );

    await _blockchain.broadcastTransaction(
      originalTxBytes,
      electrumServer: electrumServer,
    );

    final model = await _source.completeReceiver(payjoinId);

    return model.toEntity();
  }
}

class NoInputsToPayjoinException implements Exception {
  final String? message;

  const NoInputsToPayjoinException({this.message});
}
