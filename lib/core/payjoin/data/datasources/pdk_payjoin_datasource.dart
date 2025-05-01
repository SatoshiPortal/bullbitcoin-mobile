import 'dart:async';
import 'dart:developer';
import 'dart:isolate';

import 'package:bb_mobile/core/payjoin/data/models/payjoin_input_pair_model.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/transaction_parsing.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:payjoin_flutter/bitcoin_ffi.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/receive.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:payjoin_flutter/uri.dart';

class PdkPayjoinDatasource {
  final String _payjoinDirectoryUrl;
  final Dio _dio;
  final StreamController<PayjoinReceiverModel> _payjoinRequestedController;
  final StreamController<PayjoinSenderModel> _proposalSentController;
  final StreamController<PayjoinModel> _expiredController;

  // Background processing
  Isolate? _receiversIsolate;
  Isolate? _sendersIsolate;
  SendPort? _receiversIsolatePort;
  SendPort? _sendersIsolatePort;
  final Completer _receiversIsolateReady;
  final Completer _sendersIsolateReady;

  PdkPayjoinDatasource({
    String payjoinDirectoryUrl = PayjoinConstants.directoryUrl,
    required Dio dio,
  }) : _payjoinDirectoryUrl = payjoinDirectoryUrl,
       _dio = dio,
       _payjoinRequestedController = StreamController.broadcast(),
       _proposalSentController = StreamController.broadcast(),
       _expiredController = StreamController.broadcast(),
       _receiversIsolateReady = Completer(),
       _sendersIsolateReady = Completer();

  Stream<PayjoinReceiverModel> get requestsForReceivers =>
      _payjoinRequestedController.stream;

  Stream<PayjoinSenderModel> get proposalsForSenders =>
      _proposalSentController.stream;

  Stream<PayjoinModel> get expiredPayjoins => _expiredController.stream;

  Future<(OhttpKeys?, Url?)> fetchOhttpKeyAndRelay({
    required Url payjoinDirectory,
  }) async {
    Url? ohttpRelay;
    OhttpKeys? ohttpKeys;
    for (final ohttpRelayUrl in PayjoinConstants.ohttpRelayUrls) {
      try {
        final relay = await Url.fromStr(ohttpRelayUrl);
        ohttpKeys = await fetchOhttpKeys(
          ohttpRelay: relay,
          payjoinDirectory: payjoinDirectory,
        );
        ohttpRelay = relay;
        break;
      } catch (e) {
        continue;
      }
    }
    return (ohttpKeys, ohttpRelay);
  }

  Future<PayjoinReceiverModel> createReceiver({
    required String walletId,
    required String address,
    required bool isTestnet,
    required BigInt maxFeeRateSatPerVb,
    required int expireAfterSec,
  }) async {
    try {
      final payjoinDirectory = await Url.fromStr(_payjoinDirectoryUrl);

      final (ohttpKeys, ohttpRelay) = await fetchOhttpKeyAndRelay(
        payjoinDirectory: payjoinDirectory,
      );

      if (ohttpRelay == null || ohttpKeys == null) {
        throw Exception('All OHTTP relays failed');
      }

      final receiver = await Receiver.create(
        address: address,
        network: isTestnet ? Network.testnet : Network.bitcoin,
        directory: payjoinDirectory,
        ohttpKeys: ohttpKeys,
        ohttpRelay: ohttpRelay,
        expireAfter: BigInt.from(expireAfterSec),
      );

      // Create and store the model to keep track of the payjoin session
      final model =
          PayjoinModel.receiver(
                id: receiver.id(),
                address: address,
                isTestnet: isTestnet,
                receiver: receiver.toJson(),
                walletId: walletId,
                pjUri: receiver.pjUriBuilder().build().asString(),
                maxFeeRateSatPerVb: maxFeeRateSatPerVb,
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                expireAfterSec: expireAfterSec,
              )
              as PayjoinReceiverModel;

      // Start listening for a payjoin request from the sender in an isolate
      await startListeningForRequest(model);

      return model;
    } catch (e) {
      throw ReceiveCreationException(e.toString());
    }
  }

  Future<PayjoinSenderModel> createSender({
    required String walletId,
    required bool isTestnet,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  }) async {
    final expirySec = expireAfterSec ?? PayjoinConstants.defaultExpireAfterSec;
    final uri = await Uri.fromStr(bip21);

    PjUri pjUri;
    try {
      pjUri = uri.checkPjSupported();
    } catch (e) {
      throw NoValidPayjoinBip21Exception(e.toString());
    }

    final minFeeRateSatPerKwu = BigInt.from(networkFeesSatPerVb * 250);
    final senderBuilder = await SenderBuilder.fromPsbtAndUri(
      psbtBase64: originalPsbt,
      pjUri: pjUri,
    );
    final sender = await senderBuilder.buildRecommended(
      minFeeRate: minFeeRateSatPerKwu,
    );

    final senderJson = sender.toJson();

    // Create and store the model with the data needed to keep track of the
    //  payjoin session
    final model =
        PayjoinModel.sender(
              uri: uri.asString(),
              isTestnet: isTestnet,
              sender: senderJson,
              walletId: walletId,
              originalPsbt: originalPsbt,
              originalTxId: await TransactionParsing.getTxIdFromPsbt(
                originalPsbt,
              ),
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              expireAfterSec: expirySec,
            )
            as PayjoinSenderModel;

    // Start listening for a payjoin proposal from the receiver in an isolate
    await startListeningForProposal(model);

    return model;
  }

  Future<PayjoinReceiverModel> proposePayjoin({
    required PayjoinReceiverModel receiverModel,
    required FutureOr<bool> Function(Uint8List) hasOwnedInputs,
    required FutureOr<bool> Function(Uint8List) hasReceiverOutput,
    required List<PayjoinInputPairModel> inputPairs,
    required FutureOr<String> Function(String) processPsbt,
  }) async {
    final receiver = Receiver.fromJson(receiverModel.receiver);
    final request = await getRequest(receiver: receiver, dio: _dio);

    if (request == null) {
      throw Exception('No request found');
    }

    final interactiveReceiver = await request.assumeInteractiveReceiver();
    final inputsNotOwned = await interactiveReceiver.checkInputsNotOwned(
      isOwned: hasOwnedInputs,
    );
    final inputsNotSeen = await inputsNotOwned.checkNoInputsSeenBefore(
      isKnown:
          (_) =>
              false, // Assume the wallet has not seen the inputs since it is an interactive wallet
    );
    final receiverOutputs = await inputsNotSeen.identifyReceiverOutputs(
      isReceiverOutput: hasReceiverOutput,
    );
    final committedOutputs = await receiverOutputs.commitOutputs();

    final candidateInputs = await Future.wait(
      inputPairs.map(
        (input) async => await InputPair.newInstance(
          TxIn(
            previousOutput: OutPoint(txid: input.txId, vout: input.vout),
            scriptSig: await Script.newInstance(
              rawOutputScript: input.scriptSigRawOutputScript,
            ),
            sequence: input.sequence,
            witness: input.witness,
          ),
          PsbtInput(
            witnessUtxo: TxOut(
              value: input.value!,
              scriptPubkey: input.scriptPubkey,
            ),
            redeemScript:
                input.redeemScriptRawOutputScript.isEmpty
                    ? null
                    : await Script.newInstance(
                      rawOutputScript: input.redeemScriptRawOutputScript,
                    ),
            witnessScript:
                input.witnessScriptRawOutputScript.isEmpty
                    ? null
                    : await Script.newInstance(
                      rawOutputScript: input.witnessScriptRawOutputScript,
                    ),
          ),
        ),
      ),
    );

    // Try to select a privacy preserving input pair, else just stick with the
    //  first possible input pair.
    InputPair inputPair = candidateInputs.first;
    try {
      inputPair = await committedOutputs.tryPreservingPrivacy(
        candidateInputs: candidateInputs,
      );
    } catch (e) {
      debugPrint('Failed to preserve privacy: $e. Using first input pair.');
    }

    final inputsContributed = await committedOutputs.contributeInputs(
      replacementInputs: [inputPair],
    );
    final inputsCommitted = await inputsContributed.commitInputs();
    final proposal = await inputsCommitted.finalizeProposal(
      processPsbt: processPsbt,
      maxFeeRateSatPerVb: receiverModel.maxFeeRateSatPerVb,
    );

    // Now that the request is processed and the proposal is ready, send it to
    //  the sender through the payjoin directory
    await _sendPayjoinProposal(proposal);

    // Update the model with the proposal psbt so it can be known a proposal has
    //  been sent
    final proposalPsbt = await proposal.psbt();

    final updatedModel = receiverModel.copyWith(
      receiver: receiver.toJson(),
      proposalPsbt: proposalPsbt,
      txId: await TransactionParsing.getTxIdFromPsbt(proposalPsbt),
    );

    debugPrint(
      'Payjoin request processed and proposal sent for ${receiver.id()}: $proposalPsbt',
    );

    return updatedModel;
  }

  Future<void> startListeningForRequest(PayjoinReceiverModel payjoin) async {
    if (_receiversIsolate == null) {
      // Start the isolate if it is not running yet
      await _spawnReceiversIsolate();
    }
    await _receiversIsolateReady.future;
    _receiversIsolatePort?.send(payjoin.toJson());
  }

  Future<void> startListeningForProposal(PayjoinSenderModel payjoin) async {
    if (_sendersIsolate == null) {
      // Start the isolate if it is not running yet
      await _spawnSendersIsolate();
    }
    await _sendersIsolateReady.future;
    _sendersIsolatePort?.send(payjoin.toJson());
  }

  /// Starts the isolate to listen for payjoin requests.
  Future<void> _spawnReceiversIsolate() async {
    // Receive isolate
    final receivePort = ReceivePort();

    // Listen to messages from the receive isolate
    receivePort.listen((message) {
      if (message is SendPort) {
        _receiversIsolatePort = message;
        _receiversIsolateReady.complete();
      } else if (message is Map<String, dynamic>) {
        debugPrint(
          'Received message of found payjoin request in main isolate: $message',
        );
        final model = PayjoinReceiverModel.fromJson(message);

        // Send the updated payjoin model to the higher repository layers so it
        //  can be stored locally and processed further
        if (model.isExpired) {
          _expiredController.add(model);
        } else {
          // If not expired, it means a request was received
          _payjoinRequestedController.add(model);
        }
      }
    });

    debugPrint('Spawning receivers isolate');
    // Spawn the isolate
    _receiversIsolate = await Isolate.spawn(
      _receiversIsolateEntryPoint,
      receivePort.sendPort,
    );
  }

  /// Starts the isolate to request and listen for payjoin proposals.
  Future<void> _spawnSendersIsolate() async {
    // Senders isolate
    final receivePort = ReceivePort();

    // Listen for messages from the senders isolate
    receivePort.listen((message) {
      if (message is SendPort) {
        _sendersIsolatePort = message;
        _sendersIsolateReady.complete();
      } else if (message is Map<String, dynamic>) {
        final model = PayjoinSenderModel.fromJson(message);

        // Send the updated payjoin model to the higher repository layers for
        //  processing and notification to the user
        if (model.isExpired) {
          _expiredController.add(model);
        } else {
          // If not expired, it means a proposal was received
          _proposalSentController.add(model);
        }
      }
    });

    debugPrint('Spawning senders isolate');
    _sendersIsolate = await Isolate.spawn(
      _sendersIsolateEntryPoint,
      receivePort.sendPort,
    );
  }

  static Future<void> _receiversIsolateEntryPoint(SendPort sendPort) async {
    log('[Receivers Isolate] Started _receiversIsolateEntryPoint');
    // Initialize core library in the isolate too for the native pdk library
    await PConfig.initializeApp();

    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    final dio = Dio();

    // Listen for and register new receivers sent from the main isolate
    receivePort.listen((data) {
      log('[Receivers Isolate] Received data in receivers isolate: $data');
      final receiverModel = PayjoinReceiverModel.fromJson(
        data as Map<String, dynamic>,
      );
      final receiver = Receiver.fromJson(receiverModel.receiver);

      // Start checking for a payjoin request from the sender periodically
      Timer.periodic(
        const Duration(seconds: PayjoinConstants.directoryPollingInterval),
        (Timer timer) async {
          log('[Receivers Isolate] Checking for request in receivers isolate');
          try {
            final request = await getRequest(receiver: receiver, dio: dio);
            if (request != null) {
              log('[Receivers Isolate] Request found in receivers isolate');
              // The original tx bytes are needed in the main isolate for
              //  further processing so extract them here and pass them through
              //  the model
              final originalTxBytes =
                  await request.extractTxToScheduleBroadcast();
              final originalTxId =
                  await TransactionParsing.getTxIdFromTransactionBytes(
                    originalTxBytes,
                  );
              final amountSat =
                  await TransactionParsing.getAmountReceivedFromTransactionBytes(
                    originalTxBytes,
                    address: receiverModel.address,
                    isTestnet: receiverModel.isTestnet,
                  );
              log(
                '[Receivers Isolate] Request original Tx ID: $originalTxId and amount: $amountSat',
              );
              final updatedModel = receiverModel.copyWith(
                receiver: receiver.toJson(),
                originalTxBytes: originalTxBytes,
                originalTxId: originalTxId,
                amountSat: amountSat,
              );

              // Notify the main isolate so it can be processed further
              sendPort.send(updatedModel.toJson());

              // Cancel the timer since the request has been received
              timer.cancel();
            }
          } catch (e) {
            log('[Receivers Isolate] periodic timer get request exception: $e');
            if (e is PayjoinExpiredException) {
              // If the request returns an expiry error, mark the receiver as
              //  expired and notify the main isolate so it stops polling
              final updatedModel = receiverModel.copyWith(isExpired: true);
              sendPort.send(updatedModel.toJson());
              timer.cancel();
            }
          }
        },
      );
    });
  }

  static Future<void> _sendersIsolateEntryPoint(SendPort sendPort) async {
    log('[Senders Isolate] Started _sendersIsolateEntryPoint');
    // Initialize core library in the isolate too for the native pdk library
    await PConfig.initializeApp();

    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    final dio = Dio();
    // Listen for and register new receivers sent from the main isolate
    receivePort.listen((data) async {
      log('[Senders Isolate] Received data in senders isolate: $data');
      final senderModel = PayjoinSenderModel.fromJson(
        data as Map<String, dynamic>,
      );
      final sender = Sender.fromJson(senderModel.sender);
      log('[Senders Isolate] Requesting payjoin...');
      final context = await PdkPayjoinDatasource.request(
        sender: sender,
        dio: dio,
      );
      log('[Senders Isolate] Payjoin requested.');

      // Periodically check for a proposal from the receiver
      Timer.periodic(
        const Duration(seconds: PayjoinConstants.directoryPollingInterval),
        (Timer timer) async {
          log('[Senders Isolate]Checking for proposal in senders isolate');
          try {
            final proposalPsbt = await PdkPayjoinDatasource.getProposalPsbt(
              context: context,
              dio: dio,
            );

            if (proposalPsbt != null) {
              log('[Senders Isolate] Proposal found in senders isolate');
              final txId = await TransactionParsing.getTxIdFromPsbt(
                proposalPsbt,
              );
              // The proposal psbt is needed in the main isolate for
              //  further processing so send it through the model as well as
              //  its txId.
              final updatedModel = senderModel.copyWith(
                proposalPsbt: proposalPsbt,
                txId: txId,
              );

              // Notify the main isolate so the payjoin can be processed further
              sendPort.send(updatedModel.toJson());

              // Cancel the timer
              timer.cancel();
            }
          } catch (e) {
            log('[Senders Isolate] periodic timer exception: $e');
            if (e is PayjoinExpiredException) {
              // If the request returns an expiry error, mark the receiver as
              //  expired and notify the main isolate so it stops polling
              final updatedModel = senderModel.copyWith(isExpired: true);
              sendPort.send(updatedModel.toJson());
              timer.cancel();
            }
          }
        },
      );
    });
  }

  static Future<UncheckedProposal?> getRequest({
    required Receiver receiver,
    required Dio dio,
  }) async {
    try {
      final (req, context) = await receiver.extractReq();
      final ohttpResponse = await dio.post(
        req.url.asString(),
        data: req.body,
        options: Options(
          headers: {'Content-Type': req.contentType},
          responseType: ResponseType.bytes,
        ),
      );
      final proposal = await receiver.processRes(
        body: ohttpResponse.data as List<int>,
        ctx: context,
      );

      return proposal;
    } catch (e) {
      log('getRequest exception: $e');
      if (e.toString().contains('expired')) {
        throw PayjoinExpiredException(
          'Payjoin receiver $receiver.id() expired',
        );
      }
      return null;
    }
  }

  Future<void> _sendPayjoinProposal(PayjoinProposal proposal) async {
    final (req, ohttpCtx) = await proposal.extractV2Req();
    final res = await _dio.post(
      req.url.asString(),
      data: req.body,
      options: Options(
        headers: {'Content-Type': req.contentType},
        responseType: ResponseType.bytes,
      ),
    );
    await proposal.processRes(
      res: res.data as List<int>,
      ohttpContext: ohttpCtx,
    );
  }

  static Future<V2GetContext> request({
    required Sender sender,
    required Dio dio,
  }) async {
    (Request, V2PostContext)? result;

    for (final ohttpProxyUrl in PayjoinConstants.ohttpRelayUrls) {
      try {
        result = await sender.extractV2(
          ohttpProxyUrl: await Url.fromStr(ohttpProxyUrl),
        );
        break;
      } catch (e) {
        log('request exception: $e');
        continue;
      }
    }

    if (result == null) {
      throw Exception('All OHTTP relays failed');
    }

    final (req, context) = result;

    final res = await dio.post(
      req.url.asString(),
      data: req.body,
      options: Options(
        headers: {'Content-Type': req.contentType},
        responseType: ResponseType.bytes,
      ),
    );

    final getCtx = await context.processResponse(
      response: res.data as List<int>,
    );

    return getCtx;
  }

  static Future<String?> getProposalPsbt({
    required V2GetContext context,
    required Dio dio,
  }) async {
    try {
      (Request, ClientResponse)? result;

      for (final ohttpRelay in PayjoinConstants.ohttpRelayUrls) {
        try {
          result = await context.extractReq(
            ohttpRelay: await Url.fromStr(ohttpRelay),
          );
          break;
        } catch (e) {
          log('extract request exception: $e');
          continue;
        }
      }

      if (result == null) {
        throw Exception('All OHTTP relays failed');
      }

      final (req, reqCtx) = result;

      final res = await dio.post(
        req.url.asString(),
        data: req.body,
        options: Options(
          headers: {'Content-Type': req.contentType},
          responseType: ResponseType.bytes,
        ),
      );

      final proposalPsbt = await context.processResponse(
        response: res.data as List<int>,
        ohttpCtx: reqCtx,
      );

      return proposalPsbt;
    } catch (e) {
      log('getProposalPsbt exception: $e');
      if (e.toString().contains('expired')) {
        throw PayjoinExpiredException('Payjoin sender expired');
      }
      return null;
    }
  }
}

class PayjoinNotFoundException implements Exception {
  final String message;

  PayjoinNotFoundException(this.message);
}

class ReceiveCreationException implements Exception {
  final String message;

  ReceiveCreationException(this.message);
}

class NoValidPayjoinBip21Exception implements Exception {
  final String message;

  NoValidPayjoinBip21Exception(this.message);
}

class PayjoinExpiredException implements Exception {
  final String message;

  PayjoinExpiredException(this.message);
}
