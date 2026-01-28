import 'dart:async';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/domain/ports/electrum_server_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/pdk_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_input_pair_model.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bb_mobile/core/utils/constants.dart' show PayjoinConstants;
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:synchronized/synchronized.dart';

class PayjoinRepositoryImpl implements PayjoinRepository {
  final LocalPayjoinDatasource _localPayjoinDatasource;
  final PdkPayjoinDatasource _pdkPayjoinDatasource;
  final WalletMetadataDatasource _walletMetadataDatasource;
  final SeedDatasource _seed;
  final BdkWalletDatasource _bdkWallet;
  final BdkBitcoinBlockchainDatasource _blockchain;
  final ElectrumServerStorageDatasource _electrumServerStorage;
  final ElectrumSettingsStorageDatasource _electrumSettingsStorage;
  // Lock to prevent the same utxo from being used in multiple payjoin proposals
  final Lock _lock;

  final StreamController<Payjoin> _payjoinStreamController;

  PayjoinRepositoryImpl({
    required LocalPayjoinDatasource localPayjoinDatasource,
    required PdkPayjoinDatasource pdkPayjoinDatasource,
    required WalletMetadataDatasource walletMetadataDatasource,
    required SeedDatasource seedDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required BdkBitcoinBlockchainDatasource blockchainDatasource,
    required ElectrumServerStorageDatasource electrumServerStorageDatasource,
    required ElectrumSettingsStorageDatasource
    electrumSettingsStorageDatasource,
  }) : _localPayjoinDatasource = localPayjoinDatasource,
       _pdkPayjoinDatasource = pdkPayjoinDatasource,
       _walletMetadataDatasource = walletMetadataDatasource,
       _seed = seedDatasource,
       _bdkWallet = bdkWalletDatasource,
       _blockchain = blockchainDatasource,
       _electrumServerStorage = electrumServerStorageDatasource,
       _electrumSettingsStorage = electrumSettingsStorageDatasource,
       _lock = Lock(),
       _payjoinStreamController = StreamController<Payjoin>.broadcast() {
    // Listen to payjoin events from the datasource and process them
    _pdkPayjoinDatasource.requestsForReceivers.listen(_processPayjoinRequest);
    _pdkPayjoinDatasource.proposalsForSenders.listen(_processPayjoinProposal);
    _pdkPayjoinDatasource.expiredPayjoins.listen(_processExpiredPayjoin);

    // Now that the listeners are set up, we can resume processing of possible
    //  ongoing payjoins.
    _resumePayjoins();
  }

  @override
  Stream<Payjoin> get payjoinStream => _payjoinStreamController.stream;

  @override
  Future<Payjoin?> getPayjoinById(String payjoinId) async {
    final (receiver, sender) = await (
      _localPayjoinDatasource.fetchReceiver(payjoinId),
      _localPayjoinDatasource.fetchSender(payjoinId),
    ).wait;
    if (receiver != null) {
      return receiver.toEntity();
    }
    if (sender != null) {
      return sender.toEntity();
    }
    // No payjoin found with the given ID
    return null;
  }

  @override
  Future<List<Payjoin>> getPayjoins({
    String? walletId,
    bool onlyOngoing = false,
    Environment? environment,
  }) async {
    final models = await _localPayjoinDatasource.fetchAll(
      walletId: walletId,
      onlyUnfinished: onlyOngoing,
      environment: environment,
    );

    final payjoins = models.map((model) => model.toEntity()).toList();

    return payjoins;
  }

  @override
  Future<List<Payjoin>> getPayjoinsByTxId(String txId) async {
    final payjoinModels = await _localPayjoinDatasource.fetchByTxId(txId);

    return payjoinModels
        .map((payjoinModel) => payjoinModel.toEntity())
        .toList();
  }

  @override
  Future<bool> checkOhttpRelayHealth() async {
    final (ohttpKeys, ohttpRelay) = await _pdkPayjoinDatasource
        .fetchOhttpKeyAndRelay(payjoinDirectory: PayjoinConstants.directoryUrl);
    return ohttpKeys != null && ohttpRelay != null;
  }

  // TODO: Remove this and use the general frozen utxo datasource
  @override
  Future<List<({String txId, int vout})>>
  getUtxosFrozenByOngoingPayjoins() async {
    final payjoins = await _localPayjoinDatasource.fetchAll(
      onlyUnfinished: true,
    );

    final inputs = await Future.wait(
      payjoins.map((payjoin) async {
        final psbt = payjoin is PayjoinReceiverModel
            ? payjoin.proposalPsbt
            : (payjoin as PayjoinSenderModel).originalPsbt;

        if (psbt == null) {
          return null;
        }

        final walletMetadata = await _walletMetadataDatasource.fetch(
          payjoin.walletId,
        );

        if (walletMetadata == null) {
          return null;
        }

        // Extract the spent utxos from the proposal psbt
        final proposalTx = await BitcoinTx.fromPsbt(psbt);
        final spentUtxos = proposalTx.inputs
            .map((input) => (txId: input.txid, vout: input.vout))
            .toList();
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
    required int expireAfterSec,
  }) async {
    final model = await _pdkPayjoinDatasource.createReceiver(
      walletId: walletId,
      address: address,
      isTestnet: isTestnet,
      maxFeeRateSatPerVb: maxFeeRateSatPerVb,
      expireAfterSec: expireAfterSec,
    );

    // Store the payjoin receiver in the local database
    await _localPayjoinDatasource.storeReceiver(model);

    final payjoin = model.toEntity() as PayjoinReceiver;

    return payjoin;
  }

  @override
  Future<PayjoinSender> createPayjoinSender({
    required String walletId,
    required bool isTestnet,
    required String bip21,
    required String originalPsbt,
    required int amountSat,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  }) async {
    // Create the payjoin sender session
    final model = await _pdkPayjoinDatasource.createSender(
      walletId: walletId,
      isTestnet: isTestnet,
      bip21: bip21,
      originalPsbt: originalPsbt,
      networkFeesSatPerVb: networkFeesSatPerVb,
      amountSat: amountSat,
      expireAfterSec: expireAfterSec,
    );

    // Store the payjoin sender in the local database
    await _localPayjoinDatasource.storeSender(model);

    // Return a payjoin entity with send details
    final payjoin = model.toEntity();

    return payjoin as PayjoinSender;
  }

  // TODO: We should never do this here, we should use the broadcast usecase from the blockchain core
  // through a port in payjoin, but this requires refactoring payjoin first to have all this logic in the repository
  //  and not in the datasource. So this is a quick hack for now until payjoin can be refactored.
  Future<List<ElectrumServer>> _getSortedElectrumServersForNetwork(
    bool isTestnet,
  ) async {
    final (electrumServers, electrumSettings) = await (
      _electrumServerStorage.fetchAllServers(
        isTestnet: isTestnet,
        isLiquid: false,
      ),
      _electrumSettingsStorage.fetchByNetwork(
        ElectrumServerNetwork.fromEnvironment(
          isTestnet: isTestnet,
          isLiquid: false,
        ),
      ),
    ).wait;
    final customServers = electrumServers.where((s) => s.isCustom).toList();
    final serversToUse = customServers.isNotEmpty
        ? customServers
        : electrumServers;
    if (serversToUse.isEmpty) {
      throw Exception('No Electrum servers available for Bitcoin network.');
    }
    serversToUse.sort((a, b) => a.priority.compareTo(b.priority));
    return serversToUse
        .map(
          (s) => ElectrumServer(
            url: s.url,
            priority: s.priority,
            retry: electrumSettings.retry,
            timeout: electrumSettings.timeout,
            stopGap: electrumSettings.stopGap,
            validateDomain: electrumSettings.validateDomain,
            isCustom: s.isCustom,
          ),
        )
        .toList();
  }

  @override
  Future<Payjoin?> tryBroadcastOriginalTransaction(Payjoin payjoin) async {
    try {
      final servers = await _getSortedElectrumServersForNetwork(
        payjoin.isTestnet,
      );

      if (servers.isEmpty) {
        throw Exception('No Electrum servers available for Bitcoin network.');
      }

      PayjoinModel? model;
      if (payjoin is PayjoinReceiver) {
        for (int i = 0; i < servers.length; i++) {
          final serverToUse = servers[i];
          try {
            await _blockchain.broadcastTransaction(
              payjoin.originalTxBytes!,
              electrumServer: serverToUse,
            );
          } catch (e) {
            log.warning(
              'Error broadcasting original transaction with server ${serverToUse.url}: $e',
            );
            if (i == servers.length - 1) {
              rethrow; // If it's the last server, rethrow the error
            }
            continue;
          }
        }

        model = await _localPayjoinDatasource.fetchReceiver(payjoin.id);
      } else {
        payjoin as PayjoinSender;
        for (int i = 0; i < servers.length; i++) {
          final serverToUse = servers[i];
          try {
            await _blockchain.broadcastPsbt(
              payjoin.originalPsbt,
              electrumServer: serverToUse,
            );
          } catch (e) {
            log.warning(
              'Error broadcasting original PSBT with server ${serverToUse.url}: $e',
            );
            if (i == servers.length - 1) {
              rethrow; // If it's the last server, rethrow the error
            }
            continue;
          }
        }
        model = await _localPayjoinDatasource.fetchSender(payjoin.id);
      }
      log.info(
        'Original transaction broadcasted: ${payjoin.id} with txId: ${payjoin.originalTxId}',
      );

      // Update the local database with the completed payjoin

      if (model == null) {
        throw Exception('Payjoin not found locally');
      }
      final completedModel = model.copyWith(isCompleted: true);
      await _localPayjoinDatasource.update(completedModel);

      return completedModel.toEntity();
    } catch (e) {
      log.severe(
        message: 'Error broadcasting original transaction',
        error: e,
        trace: StackTrace.current,
      );
      return null;
    }
  }

  Future<void> _processPayjoinRequest(PayjoinReceiverModel model) async {
    log.info('Processing payjoin request: ${model.id}');
    // Update the local database with the new payjoin request
    await _localPayjoinDatasource.update(model);

    final payjoin = model.toEntity() as PayjoinReceiver;

    // Notify higher layers that a new payjoin request was received
    _payjoinStreamController.add(payjoin);

    // Now try to process the request
    PayjoinReceiver? result;
    try {
      final wallet = await _loadWallet(model.walletId);
      final unspentUtxos = await _bdkWallet.getUtxos(wallet: wallet);
      result = await _proposePayjoin(model, wallet, unspentUtxos);
    } catch (e) {
      log.severe(
        message: 'Error processing payjoin request',
        error: e,
        trace: StackTrace.current,
      );
      result =
          (await tryBroadcastOriginalTransaction(payjoin)) as PayjoinReceiver?;
    }

    if (result != null) {
      _payjoinStreamController.add(result);
    }
  }

  Future<void> _processPayjoinProposal(PayjoinSenderModel payjoinModel) async {
    // Update the local database with the new payjoin proposal
    await _localPayjoinDatasource.update(payjoinModel);

    final payjoin = payjoinModel.toEntity() as PayjoinSender;

    _payjoinStreamController.add(payjoin);

    PayjoinSender? result;
    try {
      final wallet = await _loadWallet(payjoin.walletId);
      final finalizedPsbt = await _bdkWallet.signPsbt(
        payjoin.proposalPsbt!,
        wallet: wallet,
      );
      result = await _broadcastPsbt(
        payjoinId: payjoin.id,
        finalizedPsbt: finalizedPsbt,
        network: payjoinModel.isTestnet
            ? Network.bitcoinTestnet
            : Network.bitcoinMainnet,
      );
      log.info(
        'Payjoin proposal broadcasted: ${payjoin.id} with txId: ${result.txId}',
      );
    } catch (e) {
      log.severe(
        message: 'Error broadcasting payjoin proposal',
        error: e,
        trace: StackTrace.current,
      );
      // TODO: Handle this, maybe by sending the original transaction instead
    }

    if (result != null) {
      _payjoinStreamController.add(result);
    }
  }

  Future<void> _processExpiredPayjoin(PayjoinModel payjoinModel) async {
    // Update the local database with the expired payjoin
    await _localPayjoinDatasource.update(payjoinModel);

    final payjoin = payjoinModel.toEntity();

    _payjoinStreamController.add(payjoin);

    // TODO: Unfreeze the utxo used in the payjoin

    if (payjoin is PayjoinReceiver && payjoin.originalTxBytes != null) {
      // If the payjoin is a receiver and it has the original transaction bytes
      //  at expiration, we broadcast the original transaction automatically.
      await tryBroadcastOriginalTransaction(payjoin);
    }
  }

  Future<void> _resumePayjoins() async {
    final models = await _localPayjoinDatasource.fetchAll(onlyUnfinished: true);
    for (final model in models) {
      if (model.isExpiryTimePassed) {
        // If the payjoin is expired, we should update the model and
        //  store it as expired so it won't be processed again unnecessarily.
        final updatedModel = model.copyWith(isExpired: true);
        await _localPayjoinDatasource.update(updatedModel);
        // Notify the repository layers that the payjoin has expired
        _payjoinStreamController.add(model.toEntity());
      } else if (model is PayjoinReceiverModel) {
        if (model.originalTxBytes == null) {
          // If the original tx bytes are not present, it means the receiver
          //  needs to listen for a payjoin request from the sender.
          await _pdkPayjoinDatasource.startListeningForRequest(model);
        } else if (model.proposalPsbt == null) {
          // If the original tx bytes are present but the proposal psbt is not,
          //  it means the receiver has already received a payjoin request and
          //  it should be processed.
          await _processPayjoinRequest(model);
        } else {
          // Todo: listen for the broadcast of the transaction
        }
      } else if (model is PayjoinSenderModel) {
        if (model.proposalPsbt == null) {
          // If the proposal psbt is not present, it means the sender needs to
          //  listen for a payjoin proposal from the receiver.
          await _pdkPayjoinDatasource.startListeningForProposal(model);
        } else {
          // If the proposal psbt is present, it means a payjoin proposal was
          //  already received  and it should be processed.
          await _processPayjoinProposal(model);
        }
      }
    }
  }

  Future<PrivateBdkWalletModel> _loadWallet(String walletId) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) throw Exception('Wallet metadata not found');

    final seed =
        await _seed.get(metadata.masterFingerprint) as MnemonicSeedModel;
    final mnemonic = seed.mnemonicWords.join(' ');

    return WalletModel.privateBdk(
          id: walletId,
          scriptType: metadata.scriptType,
          mnemonic: mnemonic,
          passphrase: seed.passphrase,
          isTestnet: metadata.isTestnet,
        )
        as PrivateBdkWalletModel;
  }

  Future<PayjoinReceiver?> _proposePayjoin(
    PayjoinReceiverModel payjoin,
    PrivateBdkWalletModel wallet,
    List<WalletUtxoModel> unspentUtxos,
  ) {
    return _lock.synchronized(() async {
      final lockedUtxos = await getUtxosFrozenByOngoingPayjoins();
      final inputPairs = _filterAvailableUtxos(unspentUtxos, lockedUtxos);

      if (inputPairs.isEmpty) {
        throw NoInputsToPayjoinException(
          'No inputs available to create a new payjoin proposal',
        );
      }

      final freshModel = await _localPayjoinDatasource.fetchReceiver(
        payjoin.id,
      );
      if (freshModel == null) throw Exception('Payjoin receiver not found');

      final updatedModel = await _pdkPayjoinDatasource.proposePayjoin(
        receiverModel: freshModel,
        hasOwnedInputs: (script) => _bdkWallet.isMine(script, wallet: wallet),
        hasReceiverOutput: (script) =>
            _bdkWallet.isMine(script, wallet: wallet),
        inputPairs: inputPairs,
        processPsbt: (psbt) => _bdkWallet.signPsbt(psbt, wallet: wallet),
      );

      await _localPayjoinDatasource.update(updatedModel);
      return updatedModel.toEntity() as PayjoinReceiver;
    });
  }

  List<PayjoinInputPairModel> _filterAvailableUtxos(
    List<WalletUtxoModel> unspent,
    List<({String txId, int vout})> locked,
  ) {
    return unspent
        .where((u) => !locked.any((l) => l.txId == u.txId && l.vout == u.vout))
        .whereType<BitcoinWalletUtxoModel>()
        .map((u) => PayjoinInputPairModel.fromWalletUtxoModel(u))
        .toList();
  }

  Future<PayjoinSender> _broadcastPsbt({
    required String payjoinId,
    required String finalizedPsbt,
    required Network network,
  }) async {
    final servers = await _getSortedElectrumServersForNetwork(
      network.isTestnet,
    );
    if (servers.isEmpty) {
      throw Exception('No Electrum servers available for Bitcoin network.');
    }

    for (int i = 0; i < servers.length; i++) {
      final serverToUse = servers[i];
      try {
        await _blockchain.broadcastPsbt(
          finalizedPsbt,
          electrumServer: serverToUse,
        );
      } catch (e) {
        log.warning(
          'Error broadcasting finalized PSBT with server ${serverToUse.url}: $e',
        );
        if (i == servers.length - 1) {
          rethrow; // If it's the last server, rethrow the error
        }
        continue;
      }
    }

    // Update the local database with the completed payjoin
    final model = await _localPayjoinDatasource.fetchSender(payjoinId);
    if (model == null) {
      throw Exception('Payjoin sender not found');
    }
    final completedModel = model.copyWith(isCompleted: true);
    await _localPayjoinDatasource.update(completedModel);

    return completedModel.toEntity() as PayjoinSender;
  }
}

class NoInputsToPayjoinException extends BullException {
  NoInputsToPayjoinException(super.message);
}
