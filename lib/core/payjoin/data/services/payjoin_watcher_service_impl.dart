import 'dart:async';

import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/services/payjoin_watcher_service.dart';
import 'package:bb_mobile/core/wallet/domain/entity/transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:flutter/material.dart';

class PayjoinWatcherServiceImpl implements PayjoinWatcherService {
  final PayjoinRepository _payjoin;
  final WalletRepository _wallet;
  final StreamController<Payjoin> _payjoinStreamController;

  PayjoinWatcherServiceImpl({
    required PayjoinRepository payjoinRepository,
    required WalletRepository walletRepository,
  })  : _payjoin = payjoinRepository,
        _wallet = walletRepository,
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
    _payjoin.proposalsForSenders.listen((payjoin) async {
      debugPrint('Received payjoin proposal: ${payjoin.id}');
      // Add the payjoin with proposal status to the stream so listeners can know
      //  that a payjoin proposal was received.
      _payjoinStreamController.add(payjoin);
      // Process the payjoin proposal
      await _processPayjoinProposal(payjoin);
    });
    _payjoin.expiredPayjoins.listen((payjoin) async {
      debugPrint('Payjoin expired: ${payjoin.id}');
      // Add the payjoin with expired status to the stream so listeners can know
      //  that a payjoin has expired.
      _payjoinStreamController.add(payjoin);

      if (payjoin is PayjoinReceiver && payjoin.originalTxBytes != null) {
        // If the payjoin is a receiver and it has the original transaction bytes
        //  at expiration, we broadcast the original transaction automatically.
        await _broadcastOriginalTransaction(payjoin);
      }
    });
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
    final proposalPsbt = payjoin.proposalPsbt;

    if (proposalPsbt == null) {
      return;
    }

    // Get the correct network from the wallet of the payjoin to make sure the
    //  tx is broadcasted on the correct network.
    final walletId = payjoin.walletId;
    Wallet wallet;
    try {
      wallet = await _wallet.getWallet(walletId);
    } catch (e) {
      debugPrint('Wallet not found for id: $walletId');
      // TODO: Mark the payjoin as failed
      return;
    }

    final network = wallet.network;

    try {
      final psbt = await Transaction.fromPsbtBase64(proposalPsbt);

      final finalizedPsbt =
          await _walletManager.sign(walletId: walletId, tx: psbt);

      final processedPayjoin = await _payjoin.broadcastPsbt(
        payjoinId: payjoin.id,
        finalizedPsbt: finalizedPsbt.toPsbtBase64(),
        network: network,
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

      if (payjoin.originalTxBytes == null) {
        debugPrint(
            'No original transaction bytes to broadcast found for payjoin:'
            ' ${payjoin.id}');
        return;
      }
      // Get the network from the wallet of the payjoin to make sure the
      //  tx is broadcasted on the correct network.
      final walletId = payjoin.walletId;
      Wallet wallet;
      try {
        wallet = await _wallet.getWallet(walletId);
      } catch (e) {
        debugPrint('Wallet not found for id: $walletId');
        // TODO: Mark the payjoin as failed
        return;
      }
      final network = wallet.network;

      final processedPayjoin = await _payjoin.broadcastOriginalTransaction(
        payjoinId: payjoin.id,
        originalTxBytes: payjoin.originalTxBytes!,
        network: network,
      );
      _payjoinStreamController.add(processedPayjoin);
    } catch (e) {
      debugPrint('Error broadcasting original transaction: $e');
      // TODO: mark the payjoin as failed
      return;
    }
  }
}
