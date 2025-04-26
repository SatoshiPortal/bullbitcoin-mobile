import 'dart:async';

import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/services/payjoin_watcher_service.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:flutter/material.dart';

class PayjoinWatcherServiceImpl implements PayjoinWatcherService {
  final PayjoinRepository _payjoin;
  final WalletRepository _wallet;
  final BitcoinWalletRepository _bitcoinWallet;
  final UtxoRepository _utxoRepository;
  final StreamController<Payjoin> _payjoinStreamController;

  PayjoinWatcherServiceImpl({
    required PayjoinRepository payjoinRepository,
    required WalletRepository walletRepository,
    required BitcoinWalletRepository bitcoinWalletRepository,
    required UtxoRepository utxoRepository,
  })  : _payjoin = payjoinRepository,
        _wallet = walletRepository,
        _bitcoinWallet = bitcoinWalletRepository,
        _utxoRepository = utxoRepository,
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
  Stream<Payjoin> get payjoins => _payjoinStreamController.stream;

  Future<void> _processPayjoinRequest(PayjoinReceiver payjoin) async {
    debugPrint('Processing payjoin request: ${payjoin.id}');
    final walletId = payjoin.walletId;
    final unspentUtxos = await _utxoRepository.getUtxos(walletId: walletId);

    try {
      final processedPayjoin = await _payjoin.processRequest(
        id: payjoin.id,
        hasOwnedInputs: (inputScript) => _bitcoinWallet.isScriptOfWallet(
          script: inputScript,
          walletId: walletId,
        ),
        hasReceiverOutput: (outputScript) => _bitcoinWallet.isScriptOfWallet(
          walletId: walletId,
          script: outputScript,
        ),
        unspentUtxos: unspentUtxos as List<BitcoinTransactionOutput>,
        processPsbt: (psbt) async {
          final signedPsbt =
              await _bitcoinWallet.signPsbt(psbt, walletId: walletId);
          return signedPsbt;
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
      final finalizedPsbt =
          await _bitcoinWallet.signPsbt(proposalPsbt, walletId: walletId);

      final processedPayjoin = await _payjoin.broadcastPsbt(
        payjoinId: payjoin.id,
        finalizedPsbt: finalizedPsbt,
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
