import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/services/payjoin_watcher_service.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';
import 'package:flutter/material.dart';

class PayjoinWatcherServiceImpl implements PayjoinWatcherService {
  final PayjoinRepository _payjoin;
  final ElectrumServerRepository _electrumServer;
  final SettingsRepository _settings;
  final WalletManagerService _walletManager;
  final StreamController<Payjoin> _payjoinStreamController;

  PayjoinWatcherServiceImpl({
    required PayjoinRepository payjoinRepository,
    required ElectrumServerRepository electrumServerRepository,
    required SettingsRepository settingsRepository,
    required WalletManagerService walletManagerService,
  })  : _payjoin = payjoinRepository,
        _electrumServer = electrumServerRepository,
        _settings = settingsRepository,
        _walletManager = walletManagerService,
        _payjoinStreamController = StreamController<Payjoin>.broadcast() {
    // Listen to payjoin events from the repository and process them
    _payjoin.requestsForReceivers.listen((payjoin) async {
      debugPrint('Received payjoin request: ${payjoin.id}');
      // Add the payjoin with request status to the stream so listeners can know
      //  that a payjoin request was received.
      _payjoinStreamController.add(payjoin);
      // Process the payjoin request
      await _processPayjoinRequest(
        payjoin,
      );
    });
    _payjoin.proposalsForSenders
        .listen((payjoin) => _processPayjoinProposal(payjoin));
  }

  @override
  Stream<Payjoin> get payjoins =>
      _payjoinStreamController.stream.asBroadcastStream();

  Future<void> _processPayjoinRequest(PayjoinReceiver payjoin) async {
    debugPrint('Processing payjoin request: ${payjoin.id}');
    final walletId = payjoin.walletId;
    final unspentUtxos =
        await _walletManager.getUnspentUtxos(walletId: walletId);

    try {
      final processedPayjoin = await _payjoin.processRequest(
        id: payjoin.id,
        hasOwnedInputs: (inputScript) => _walletManager.isOwnedByWallet(
          walletId: walletId,
          scriptBytes: inputScript,
        ),
        hasReceiverOutput: (outputScript) => _walletManager.isOwnedByWallet(
          walletId: walletId,
          scriptBytes: outputScript,
        ),
        unspentUtxos: unspentUtxos,
        processPsbt: (psbt) async {
          final tx = await Transaction.fromPsbtBase64(psbt);
          final signedPsbt =
              await _walletManager.sign(walletId: walletId, tx: tx);
          return signedPsbt.toPsbtBase64();
        },
      );
      _payjoinStreamController.add(processedPayjoin);
    } catch (e) {
      debugPrint('Error processing payjoin request: $e');
      // The payjoin request was not processed correctly, so we need to broadcast
      // the original transaction instead.
      _broadcastOriginalTransaction(payjoin);
    }
  }

  Future<void> _processPayjoinProposal(PayjoinSender payjoin) async {
    final walletId = payjoin.walletId;
    final proposalPsbt = payjoin.proposalPsbt;
    final environment = await _settings.getEnvironment();
    final network = Network.fromEnvironment(
      isTestnet: environment.isTestnet,
      isLiquid: false,
    );
    final electrumServer =
        await _electrumServer.getElectrumServer(network: network);

    if (proposalPsbt == null) {
      return;
    }

    try {
      final psbt = await Transaction.fromPsbtBase64(proposalPsbt);

      final finalizedPsbt =
          await _walletManager.sign(walletId: walletId, tx: psbt);

      final processedPayjoin = await _payjoin.broadcastPsbt(
        payjoinId: payjoin.id,
        finalizedPsbt: finalizedPsbt.toPsbtBase64(),
        electrumServer: electrumServer,
      );

      _payjoinStreamController.add(processedPayjoin);
    } catch (e) {
      // TODO: Handle this, maybe by sending the original transaction instead
      debugPrint('Error broadcasting payjoin: $e');
    }
  }

  Future<void> _broadcastOriginalTransaction(PayjoinReceiver payjoin) async {
    try {
      debugPrint(
        'Broadcasting original transaction for payjoin: ${payjoin.id}',
      );
      // Get the correct network from the wallet metadata using the walletId from
      //  the payjoin to be able to get the correct Electrum server to broadcast
      //  the transaction.
      final wallet = await _walletManager.getWallet(payjoin.walletId);
      if (wallet == null) {
        debugPrint('Wallet not found for id: ${payjoin.walletId}');
        // TODO: Mark the payjoin as failed
        return;
      }
      final network = wallet.network;
      final electrumServer =
          await _electrumServer.getElectrumServer(network: network);

      // Broadcast the original transaction using the Electrum server
      if (payjoin.originalTxBytes == null) {
        debugPrint(
            'No original transaction bytes to broadcast found for payjoin:'
            ' ${payjoin.id}');
        return;
      }
      final processedPayjoin = await _payjoin.broadcastOriginalTransaction(
        payjoinId: payjoin.id,
        originalTxBytes: payjoin.originalTxBytes!,
        electrumServer: electrumServer,
      );
      _payjoinStreamController.add(processedPayjoin);
    } catch (e) {
      debugPrint('Error broadcasting original transaction: $e');
      // TODO: mark the payjoin as failed
      return;
    }
  }
}
