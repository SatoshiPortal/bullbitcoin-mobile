import 'dart:async';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_input_pair_model.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/transaction_parsing.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet/impl/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

class PayjoinRepositoryImpl implements PayjoinRepository {
  final PayjoinDatasource _source;
  final WalletMetadataDatasource _walletMetadata;
  final SeedDatasource _seed;
  final BdkWalletDatasource _bdkWallet;
  final BdkBitcoinBlockchainDatasource _blockchain;
  final ElectrumServerStorageDatasource _electrumServerStorage;
  // Lock to prevent the same utxo from being used in multiple payjoin proposals
  final Lock _lock;

  PayjoinRepositoryImpl({
    required PayjoinDatasource payjoinDatasource,
    required WalletMetadataDatasource walletMetadataDatasource,
    required SeedDatasource seedDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required BdkBitcoinBlockchainDatasource blockchainDatasource,
    required ElectrumServerStorageDatasource electrumServerStorageDatasource,
  })  : _source = payjoinDatasource,
        _walletMetadata = walletMetadataDatasource,
        _seed = seedDatasource,
        _bdkWallet = bdkWalletDatasource,
        _blockchain = blockchainDatasource,
        _electrumServerStorage = electrumServerStorageDatasource,
        _lock = Lock();

  @override
  Stream<PayjoinReceiver> get requestsForReceivers =>
      _source.requestsForReceivers.map(
        (payjoinModel) => payjoinModel.toEntity() as PayjoinReceiver,
      );
  @override
  Stream<PayjoinSender> get proposalsForSenders =>
      _source.proposalsForSenders.map(
        (payjoinModel) => payjoinModel.toEntity() as PayjoinSender,
      );
  @override
  Stream<Payjoin> get expiredPayjoins => _source.expiredPayjoins.map(
        (payjoinModel) => payjoinModel.toEntity(),
      );

  @override
  Future<Payjoin?> getPayjoinByTxId(String txId) async {
    final payjoinModels = await _source.getAll();

    Payjoin? payjoin;
    try {
      final payjoinModel = payjoinModels.firstWhere(
        (payjoin) => payjoin.txId == txId,
      );
      payjoin = payjoinModel.toEntity();
    } catch (e) {
      debugPrint('Payjoin not found for txId: $txId');
    }

    return payjoin;
  }

  // TODO: Remove this and use the general frozen utxo datasource
  @override
  Future<List<({String txId, int vout})>>
      getUtxosFrozenByOngoingPayjoins() async {
    final payjoins = await _source.getAll(onlyOngoing: true);

    final inputs = await Future.wait(
      payjoins.map((payjoin) async {
        final psbt = payjoin is PayjoinReceiverModel
            ? payjoin.proposalPsbt
            : (payjoin as PayjoinSenderModel).originalPsbt;

        if (psbt == null) {
          return null;
        }

        final walletMetadata = await _walletMetadata.get(payjoin.walletId);
        if (walletMetadata == null) {
          return null;
        }

        // Extract the spent utxos from the proposal psbt
        final spentUtxos = await TransactionParsing.extractSpentUtxosFromPsbt(
          psbt,
          isTestnet: walletMetadata.isTestnet,
        );
        return spentUtxos;
      }),
    );

    return inputs
        .whereType<List<({String txId, int vout})>>()
        .expand((element) => element)
        .toList();
  }

  @override
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

    final payjoin = model.toEntity();

    return payjoin as PayjoinReceiver;
  }

  @override
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

    return payjoin as PayjoinSender;
  }

  @override
  Future<List<Payjoin>> getAll({
    int? offset,
    int? limit,
    //bool? completed,
  }) async {
    final models = await _source.getAll();

    final payjoins = models
        .map(
          (model) => model.toEntity(),
        )
        .toList();

    return payjoins;
  }

  @override
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

      final pdkInputPairs = unspentUtxos
          .where((unspent) {
            final isUtxoLocked = lockedUtxos.any((locked) {
              return unspent.txId == locked.txId && unspent.vout == locked.vout;
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

      return model.toEntity() as PayjoinReceiver;
    });

    return payjoinReceiver;
  }

  @override
  Future<String> signPsbt({
    required String walletId,
    required String psbt,
  }) async {
    final walletMetadata = await _walletMetadata.get(walletId);

    if (walletMetadata == null) {
      throw Exception('Wallet metadata not found');
    }

    final seed = await _seed.get(
      walletMetadata.masterFingerprint,
    ) as MnemonicSeed;
    final mnemonic = seed.mnemonicWords.join(' ');

    final wallet = WalletModel.privateBdk(
      id: walletId,
      scriptType: ScriptType.fromName(walletMetadata.scriptType),
      mnemonic: mnemonic,
      passphrase: seed.passphrase,
      isTestnet: walletMetadata.isTestnet,
    ) as PrivateBdkWalletModel;

    final signedPsbt = await _bdkWallet.signPsbt(psbt, wallet: wallet);

    return signedPsbt;
  }

  @override
  Future<PayjoinSender> broadcastPsbt({
    required String payjoinId,
    required String finalizedPsbt,
    required Network network,
  }) async {
    // TODO: Should we get all the electrum servers and try another one if the
    //  first one fails?
    final electrumServer = await _electrumServerStorage.getByProvider(
          ElectrumServerProvider.blockstream,
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

    final model = await _source.completeSender(
      payjoinId,
    );

    return model.toEntity() as PayjoinSender;
  }

  @override
  Future<PayjoinReceiver> broadcastOriginalTransaction({
    required String payjoinId,
    required Uint8List originalTxBytes,
    required Network network,
  }) async {
    // TODO: Should we get all the electrum servers and try another one if the
    //  first one fails?
    final electrumServer = await _electrumServerStorage.getByProvider(
          ElectrumServerProvider.blockstream,
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

    final model = await _source.completeReceiver(
      payjoinId,
    );

    return model.toEntity() as PayjoinReceiver;
  }
}

class NoInputsToPayjoinException implements Exception {
  final String? message;

  const NoInputsToPayjoinException({this.message});
}
