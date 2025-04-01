import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:isolate';

import 'package:bb_mobile/core/payjoin/data/models/payjoin_input_pair_model.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:payjoin_flutter/bitcoin_ffi.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/receive.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:payjoin_flutter/uri.dart';

class PayjoinDatasource {
  final String _payjoinDirectoryUrl;
  final Dio _dio;
  final KeyValueStorageDatasource<String> _storage;
  final StreamController<PayjoinReceiverModel> _payjoinRequestedController =
      StreamController.broadcast();
  final StreamController<PayjoinSenderModel> _proposalSentController =
      StreamController.broadcast();
  final StreamController<PayjoinModel> _expiredController =
      StreamController.broadcast();

  // Background processing
  Isolate? _receiversIsolate;
  Isolate? _sendersIsolate;
  SendPort? _receiversIsolatePort;
  SendPort? _sendersIsolatePort;
  final Completer _receiversIsolateReady;
  final Completer _sendersIsolateReady;

  PayjoinDatasource({
    String payjoinDirectoryUrl = PayjoinConstants.directoryUrl,
    required Dio dio,
    required KeyValueStorageDatasource<String> storage,
  })  : _payjoinDirectoryUrl = payjoinDirectoryUrl,
        _dio = dio,
        _storage = storage,
        _receiversIsolateReady = Completer(),
        _sendersIsolateReady = Completer() {
    _resumePayjoins();
  }

  Stream<PayjoinReceiverModel> get requestsForReceivers =>
      _payjoinRequestedController.stream.asBroadcastStream();

  Stream<PayjoinSenderModel> get proposalsForSenders =>
      _proposalSentController.stream.asBroadcastStream();

  Stream<PayjoinModel> get expiredPayjoins =>
      _expiredController.stream.asBroadcastStream();

  Future<PayjoinReceiverModel> createReceiver({
    required String walletId,
    required String address,
    required bool isTestnet,
    required BigInt maxFeeRateSatPerVb,
    int? expireAfterSec,
  }) async {
    try {
      final expirySec =
          expireAfterSec ?? PayjoinConstants.defaultExpireAfterSec;
      final payjoinDirectory = await Url.fromStr(_payjoinDirectoryUrl);

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

      if (ohttpRelay == null || ohttpKeys == null) {
        throw Exception('All OHTTP relays failed');
      }

      final receiver = await Receiver.create(
        address: address,
        network: isTestnet ? Network.testnet : Network.bitcoin,
        directory: payjoinDirectory,
        ohttpKeys: ohttpKeys,
        ohttpRelay: ohttpRelay,
        expireAfter: BigInt.from(expirySec),
      );

      // Create and store the model to keep track of the payjoin session
      final model = PayjoinModel.receiver(
        id: receiver.id(),
        receiver: receiver.toJson(),
        walletId: walletId,
        pjUri: receiver.pjUriBuilder().build().asString(),
        maxFeeRateSatPerVb: maxFeeRateSatPerVb,
        expireAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
            expirySec, // Expire after the given seconds
      ) as PayjoinReceiverModel;
      await _store(model);

      // Start listening for a payjoin request from the sender in an isolate
      if (_receiversIsolate == null) {
        await _spawnReceiversIsolate();
      }
      // Make sure the isolate is ready and so messages can be send over the port
      await _receiversIsolateReady.future;
      // We send the model to the isolate so the isolate has all the information
      //  it needs.
      _receiversIsolatePort?.send(model.toJson());

      return model;
    } catch (e) {
      throw ReceiveCreationException(e.toString());
    }
  }

  Future<PayjoinSenderModel> createSender({
    required String walletId,
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
    final model = PayjoinModel.sender(
      uri: uri.asString(),
      sender: senderJson,
      walletId: walletId,
      originalPsbt: originalPsbt,
      expireAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
          expirySec, // Expire after the given seconds
    ) as PayjoinSenderModel;
    await _store(model);

    // Start listening for a payjoin proposal from the receiver in an isolate
    if (_sendersIsolate == null) {
      await _spawnSendersIsolate();
    }
    // Wait until the senders isolate is set to send messages to the port
    await _sendersIsolateReady.future;
    // Send the model so the isolate has all the info about the payjoin
    _sendersIsolatePort?.send(model.toJson());

    return model;
  }

  Future<PayjoinModel?> get(String id) async {
    final value = await _storage.getValue(id);
    if (value == null) {
      return null;
    }
    final json = jsonDecode(value) as Map<String, dynamic>;
    if (json['uri'] != null) {
      return PayjoinSenderModel.fromJson(json);
    } else {
      return PayjoinReceiverModel.fromJson(json);
    }
  }

  Future<List<PayjoinModel>> getAll({bool onlyOngoing = false}) async {
    final entries = await _storage.getAll();
    final models = <PayjoinModel>[];

    for (final value in entries.values) {
      final json = jsonDecode(value) as Map<String, dynamic>;
      if (json['uri'] != null) {
        final senderModel = PayjoinSenderModel.fromJson(json);
        if (onlyOngoing && (senderModel.isCompleted || senderModel.isExpired)) {
          continue;
        }
        models.add(senderModel);
      } else {
        final receiverModel = PayjoinReceiverModel.fromJson(json);
        if (onlyOngoing &&
            (receiverModel.isCompleted || receiverModel.isExpired)) {
          continue;
        }
        models.add(receiverModel);
      }
    }
    return models;
  }

  Future<void> delete(String id) async {
    await _storage.deleteValue(id);
  }

  Future<PayjoinReceiverModel> processRequest({
    required String id,
    required FutureOr<bool> Function(Uint8List) hasOwnedInputs,
    required FutureOr<bool> Function(Uint8List) hasReceiverOutput,
    required List<PayjoinInputPairModel> inputPairs,
    required FutureOr<String> Function(String) processPsbt,
  }) async {
    final model = await get(id) as PayjoinReceiverModel?;

    if (model == null) {
      throw Exception('No model found');
    }

    final receiver = Receiver.fromJson(model.receiver);
    final request = await getRequest(receiver: receiver, dio: _dio);

    if (request == null) {
      throw Exception('No request found');
    }

    final interactiveReceiver = await request.assumeInteractiveReceiver();
    final inputsNotOwned = await interactiveReceiver.checkInputsNotOwned(
      isOwned: hasOwnedInputs,
    );
    final inputsNotSeen = await inputsNotOwned.checkNoInputsSeenBefore(
      isKnown: (_) =>
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
            witnessUtxo:
                TxOut(value: input.value, scriptPubkey: input.scriptPubkey),
            redeemScript: input.redeemScriptRawOutputScript.isEmpty
                ? null
                : await Script.newInstance(
                    rawOutputScript: input.redeemScriptRawOutputScript,
                  ),
            witnessScript: input.witnessScriptRawOutputScript.isEmpty
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

    final inputsContributed =
        await committedOutputs.contributeInputs(replacementInputs: [inputPair]);
    final inputsCommitted = await inputsContributed.commitInputs();
    final proposal = await inputsCommitted.finalizeProposal(
      processPsbt: processPsbt,
      maxFeeRateSatPerVb: model.maxFeeRateSatPerVb,
    );

    // Now that the request is processed and the proposal is ready, send it to
    //  the sender through the payjoin directory
    await _proposePayjoin(proposal);

    // Update the model with the proposal psbt so it can be known a proposal has
    //  been sent
    final proposalPsbt = await proposal.psbt();
    final updatedModel = model.copyWith(
      receiver: receiver.toJson(),
      proposalPsbt: proposalPsbt,
    );
    await _store(updatedModel);

    debugPrint(
      'Payjoin request processed and proposal sent for $id: $proposalPsbt',
    );

    return updatedModel;
  }

  Future<PayjoinSenderModel> completeSender(
    String uri, {
    required String txId,
  }) async {
    final model = await get(uri) as PayjoinSenderModel?;

    if (model == null) {
      throw Exception('No model found');
    }

    final updatedModel = model.copyWith(
      txId: txId,
      isCompleted: true, // Nothing more to do from the sender side
    );
    await _store(updatedModel);

    return updatedModel;
  }

  Future<PayjoinReceiverModel> completeReceiver(
    String id, {
    required String txId,
  }) async {
    final model = await get(id) as PayjoinReceiverModel?;

    if (model == null) {
      throw Exception('No model found');
    }

    final updatedModel = model.copyWith(
      txId: txId,
      isCompleted: true, // Nothing more to do from the sender side
    );
    await _store(updatedModel);

    return updatedModel;
  }

  Future<void> _store(PayjoinModel model) async {
    final value = jsonEncode(model.toJson());
    if (model is PayjoinReceiverModel) {
      await _storage.saveValue(key: model.id, value: value);
    } else if (model is PayjoinSenderModel) {
      await _storage.saveValue(key: model.uri, value: value);
    }
  }

  /// Starts the isolate to listen for payjoin requests.
  Future<void> _spawnReceiversIsolate() async {
    // Receive isolate
    final receivePort = ReceivePort();

    // Listen to messages from the receive isolate
    receivePort.listen((message) async {
      if (message is SendPort) {
        _receiversIsolatePort = message;
        _receiversIsolateReady.complete();
      } else if (message is Map<String, dynamic>) {
        debugPrint(
          'Received message of found payjoin request in main isolate: $message',
        );
        final model = PayjoinReceiverModel.fromJson(message);
        // Store the model received from the isolate
        await _store(model);

        // Send the updated payjoin model to the higher repository layers for
        //  processing and/or notification to the user
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
    _receiversIsolate =
        await Isolate.spawn(_receiversIsolateEntryPoint, receivePort.sendPort);
  }

  /// Starts the isolate to request and listen for payjoin proposals.
  Future<void> _spawnSendersIsolate() async {
    // Senders isolate
    final receivePort = ReceivePort();

    // Listen for messages from the senders isolate
    receivePort.listen((message) async {
      if (message is SendPort) {
        _sendersIsolatePort = message;
        _sendersIsolateReady.complete();
      } else if (message is Map<String, dynamic>) {
        final model = PayjoinSenderModel.fromJson(message);
        // Store the model received from the isolate
        await _store(model);

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
    _sendersIsolate =
        await Isolate.spawn(_sendersIsolateEntryPoint, receivePort.sendPort);
  }

  static Future<void> _receiversIsolateEntryPoint(SendPort sendPort) async {
    log('[Receivers Isolate] Started _receiversIsolateEntryPoint');
    // Initialize core library in the isolate too for the native pdk library
    await PConfig.initializeApp();

    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    final dio = Dio();

    // Listen for and register new receivers sent from the main isolate
    receivePort.listen(
      (data) {
        log('[Receivers Isolate] Received data in receivers isolate: $data');
        final receiverModel =
            PayjoinReceiverModel.fromJson(data as Map<String, dynamic>);
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
                final updatedModel = receiverModel.copyWith(
                  receiver: receiver.toJson(),
                  originalTxBytes: originalTxBytes,
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
                final updatedModel = receiverModel.copyWith(
                  isExpired: true,
                );
                sendPort.send(updatedModel.toJson());
                timer.cancel();
              }
            }
          },
        );
      },
    );
  }

  static Future<void> _sendersIsolateEntryPoint(SendPort sendPort) async {
    log('[Senders Isolate] Started _sendersIsolateEntryPoint');
    // Initialize core library in the isolate too for the native pdk library
    await PConfig.initializeApp();

    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    final dio = Dio();
    // Listen for and register new receivers sent from the main isolate
    receivePort.listen(
      (data) async {
        log('[Senders Isolate] Received data in senders isolate: $data');
        final senderModel =
            PayjoinSenderModel.fromJson(data as Map<String, dynamic>);
        final sender = Sender.fromJson(senderModel.sender);
        log('[Senders Isolate] Requesting payjoin...');
        final context =
            await PayjoinDatasource.request(sender: sender, dio: dio);
        log('[Senders Isolate] Payjoin requested.');

        // Periodically check for a proposal from the receiver
        Timer.periodic(
          const Duration(seconds: PayjoinConstants.directoryPollingInterval),
          (Timer timer) async {
            log('[Senders Isolate]Checking for proposal in senders isolate');
            try {
              final proposalPsbt = await PayjoinDatasource.getProposalPsbt(
                context: context,
                dio: dio,
              );
              if (proposalPsbt != null) {
                log('[Senders Isolate] Proposal found in senders isolate');
                // The proposal psbt is needed in the main isolate for
                //  further processing so send it through the model
                final updatedModel = senderModel.copyWith(
                  proposalPsbt: proposalPsbt,
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
                final updatedModel = senderModel.copyWith(
                  isExpired: true,
                );
                sendPort.send(updatedModel.toJson());
                timer.cancel();
              }
            }
          },
        );
      },
    );
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
          headers: {
            'Content-Type': req.contentType,
          },
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

  Future<void> _proposePayjoin(
    PayjoinProposal proposal,
  ) async {
    final (req, ohttpCtx) = await proposal.extractV2Req();
    final res = await _dio.post(
      req.url.asString(),
      data: req.body,
      options: Options(
        headers: {
          'Content-Type': req.contentType,
        },
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
        headers: {
          'Content-Type': req.contentType,
        },
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
          headers: {
            'Content-Type': req.contentType,
          },
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
        throw PayjoinExpiredException(
          'Payjoin sender expired',
        );
      }
      return null;
    }
  }

  Future<void> _resumePayjoins() async {
    final models = await getAll(onlyOngoing: true);
    for (final model in models) {
      if (model.isExpireAtPassed) {
        // If the payjoin is expired, we should update the model and
        //  store it as expired so it won't be processed again unnecessarily.
        final updatedModel = model.copyWith(
          isExpired: true,
        );
        await _store(updatedModel);
        // Notify the repository layers that the payjoin has expired
        _expiredController.add(model);
      } else if (model is PayjoinReceiverModel) {
        if (model.originalTxBytes == null) {
          // If the original tx bytes are not present, it means the receiver
          //  needs to listen for a payjoin request from the sender, we do this
          //  in the isolate.
          if (_receiversIsolate == null) {
            // Start the isolate if it is not running yet
            await _spawnReceiversIsolate();
          }
          await _receiversIsolateReady.future;
          _receiversIsolatePort?.send(model.toJson());
        } else if (model.proposalPsbt == null) {
          // If the original tx bytes are present but the proposal psbt is not,
          //  it means the receiver has received a payjoin request and it should
          //  be processed with help of upper layers, so we notify them through
          //  the stream.
          _payjoinRequestedController.add(model);
        } else {
          // Todo: add to stream to notify that a proposal was already sent and
          // listen for the broadcasted transaction
        }
      } else if (model is PayjoinSenderModel) {
        if (model.proposalPsbt == null) {
          // If the proposal psbt is not present, it means no proposal has been
          //  sent yet, so we need to request one from the receiver through the
          //  payjoin directory. We do this and wait for the proposal in the
          //  isolate.
          if (_sendersIsolate == null) {
            // Start the isolate if it is not running yet
            await _spawnSendersIsolate();
          }
          await _sendersIsolateReady.future;
          _sendersIsolatePort?.send(model.toJson());
        } else {
          // If the proposal psbt is present, it means a payjoin proposal was
          //  sent by the receiver already and it should be processed and
          //  broadcasted by upper layers, so we notify them through the stream.
          _proposalSentController.add(model);
        }
      }
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
