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
import 'package:bb_mobile/core/utxo/domain/entities/utxo.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/private_wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
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

  @override
  Future<List<Utxo>> getInputsFromOngoingPayjoins() async {
    final inputs = <Utxo>[];
    final payjoins = await _source.getAll(onlyOngoing: true);
    for (final payjoin in payjoins) {
      String? psbt;
      switch (payjoin) {
        case final PayjoinReceiverModel receiver:
          psbt = receiver.proposalPsbt;
          debugPrint('ongoing receiver with psbt: $psbt');
        case final PayjoinSenderModel sender:
          psbt = sender.originalPsbt;
          debugPrint('ongoing sender with psbt: $psbt');
      }
      if (psbt != null) {
        // Extract the inputs from the proposal psbt
        final psbtInputs = await TransactionParsing.extractInputsFromPsbt(psbt);
        debugPrint('extracted inputs $psbtInputs, for psbt: $psbt');
        inputs.addAll(psbtInputs);
      }
    }

    debugPrint('ongoingPayjoins: $payjoins');
    debugPrint('inputsFromOngoingPayjoins: $inputs');

    return inputs;
  }

  @override
  Future<PayjoinReceiver> createPayjoinReceiver({
    required String origin,
    required String address,
    required bool isTestnet,
    required BigInt maxFeeRateSatPerVb,
    int? expireAfterSec,
  }) async {
    final model = await _source.createReceiver(
      origin: origin,
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
    required String origin,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  }) async {
    // Create the payjoin sender session
    final model = await _source.createSender(
      origin: origin,
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
    required List<Utxo> unspentUtxos,
    required FutureOr<String> Function(String) processPsbt,
  }) async {
    // A lock is needed here to make sure the proposal of a payjoin is stored
    //  before another payjoin checks for available inputs to create a proposal
    final payjoinReceiver = await _lock.synchronized(() async {
      debugPrint('unspentUtxos: $unspentUtxos');
      // Make sure the inputs to select from for the proposal are not used by
      //  ongoing payjoins already
      final lockedInputs = await getInputsFromOngoingPayjoins();
      debugPrint('lockedInputs: $lockedInputs');

      final pdkInputPairs = unspentUtxos
          .where((utxo) {
            final isUtxoLocked = lockedInputs.any((input) {
              return input.txId == utxo.txId && input.vout == utxo.vout;
            });

            return !isUtxoLocked;
          })
          .map((utxo) => PayjoinInputPairModel.fromUtxo(utxo))
          .toList();

      debugPrint('pdkInputPairs: $pdkInputPairs');

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
    required String origin,
    required String psbt,
  }) async {
    final walletMetadata = await _walletMetadata.get(origin);

    if (walletMetadata == null) {
      throw Exception('Wallet metadata not found');
    }

    final seed = await _seed.get(
      walletMetadata.masterFingerprint,
    ) as MnemonicSeed;
    final mnemonic = seed.mnemonicWords.join(' ');

    final wallet = PrivateBdkWalletModel(
      scriptType: ScriptType.fromName(walletMetadata.scriptType),
      mnemonic: mnemonic,
      passphrase: seed.passphrase,
      isTestnet: walletMetadata.isTestnet,
      dbName: origin,
    );

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
