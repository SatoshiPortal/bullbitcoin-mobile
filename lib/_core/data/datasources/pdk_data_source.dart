import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:bb_mobile/_core/data/datasources/key_value_stores/key_value_storage_data_source.dart';
import 'package:bb_mobile/_core/data/models/pdk_input_pair_model.dart';
import 'package:bb_mobile/_core/data/models/pdk_payjoin_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:payjoin_flutter/bitcoin_ffi.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/receive.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:payjoin_flutter/src/generated/frb_generated.dart';
import 'package:payjoin_flutter/uri.dart';

abstract class PdkDataSource {
  // requestsForReceivers is a stream that emits a PdkPayjoinReceiverModel every
  //  time a payjoin request (original tx psbt) is received from a sender.
  Stream<PdkPayjoinReceiverModel> get requestsForReceivers;
  // proposalsForSenders is a stream that emits a PdkPayjoinSenderModel every time a
  //  payjoin proposal (payjoin tx psbt) was sent by a receiver for a sender.
  Stream<PdkPayjoinSenderModel> get proposalsForSenders;
  Future<PdkPayjoinReceiverModel> createReceiver({
    required String walletId,
    required String address,
    required bool isTestnet,
    required BigInt maxFeeRateSatPerVb,
    int? expireAfterSec,
  });
  Future<PdkPayjoinSenderModel> createSender({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
  });
  Future<PdkPayjoinModel?> get(String id);
  Future<List<PdkPayjoinModel>> getAll();
  Future<void> delete(String id);
  Future<PdkPayjoinReceiverModel> processRequest({
    required String id,
    required FutureOr<bool> Function(Uint8List) hasOwnedInputs,
    required FutureOr<bool> Function(Uint8List) hasReceiverOutput,
    required List<PdkInputPairModel> inputPairs,
    required FutureOr<String> Function(String) processPsbt,
  });
  Future<PdkPayjoinSenderModel> completeSender(
    String uri, {
    required String txId,
  });
}

class PdkDataSourceImpl implements PdkDataSource {
  static const String ohttpRelayUrl = 'https://pj.bobspacebkk.com';

  final String _payjoinDirectoryUrl;
  final Dio _dio;
  final KeyValueStorageDataSource<String> _storage;
  final StreamController<PdkPayjoinReceiverModel> _payjoinRequestedController =
      StreamController.broadcast();
  final StreamController<PdkPayjoinSenderModel> _proposalSentController =
      StreamController.broadcast();

  // Background processing
  Isolate? _receiversIsolate;
  Isolate? _sendersIsolate;
  SendPort? _receiversIsolatePort;
  SendPort? _sendersIsolatePort;
  final Completer _receiversIsolateReady;
  final Completer _sendersIsolateReady;

  PdkDataSourceImpl({
    String payjoinDirectoryUrl = 'https://payjo.in',
    required Dio dio,
    required KeyValueStorageDataSource<String> storage,
  })  : _payjoinDirectoryUrl = payjoinDirectoryUrl,
        _dio = dio,
        _storage = storage,
        _receiversIsolateReady = Completer(),
        _sendersIsolateReady = Completer() {
    _resumePayjoins();
  }

  @override
  Stream<PdkPayjoinReceiverModel> get requestsForReceivers =>
      _payjoinRequestedController.stream.asBroadcastStream();

  @override
  Stream<PdkPayjoinSenderModel> get proposalsForSenders =>
      _proposalSentController.stream.asBroadcastStream();

  @override
  Future<PdkPayjoinReceiverModel> createReceiver({
    required String walletId,
    required String address,
    required bool isTestnet,
    required BigInt maxFeeRateSatPerVb,
    int? expireAfterSec,
  }) async {
    try {
      final payjoinDirectory = await Url.fromStr(_payjoinDirectoryUrl);
      final ohttpRelay = await Url.fromStr(ohttpRelayUrl);
      final ohttpKeys = await fetchOhttpKeys(
        ohttpRelay: ohttpRelay,
        payjoinDirectory: payjoinDirectory,
      );

      final receiver = await Receiver.create(
        address: address,
        network: isTestnet ? Network.testnet : Network.bitcoin,
        directory: payjoinDirectory,
        ohttpKeys: ohttpKeys,
        ohttpRelay: ohttpRelay,
        expireAfter:
            expireAfterSec == null ? null : BigInt.from(expireAfterSec),
      );

      // Create and store the model to keep track of the payjoin session
      final model = PdkPayjoinModel.receiver(
        id: receiver.id(),
        receiver: receiver.toJson(),
        walletId: walletId,
        pjUri: receiver.pjUriBuilder().build().asString(),
        maxFeeRateSatPerVb: maxFeeRateSatPerVb,
      ) as PdkPayjoinReceiverModel;
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

  @override
  Future<PdkPayjoinSenderModel> createSender({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
  }) async {
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
    final model = PdkPayjoinModel.sender(
      uri: uri.asString(),
      sender: senderJson,
      walletId: walletId,
      originalPsbt: originalPsbt,
    ) as PdkPayjoinSenderModel;
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

  @override
  Future<PdkPayjoinModel?> get(String id) async {
    final value = await _storage.getValue(id);
    if (value == null) {
      return null;
    }
    final json = jsonDecode(value) as Map<String, dynamic>;
    if (json['uri'] != null) {
      return PdkPayjoinSenderModel.fromJson(json);
    } else {
      return PdkPayjoinReceiverModel.fromJson(json);
    }
  }

  @override
  Future<List<PdkPayjoinModel>> getAll() async {
    final entries = await _storage.getAll();
    final models = <PdkPayjoinModel>[];

    for (final value in entries.values) {
      final json = jsonDecode(value) as Map<String, dynamic>;
      if (json['uri'] != null) {
        models.add(PdkPayjoinSenderModel.fromJson(json));
      } else {
        models.add(PdkPayjoinReceiverModel.fromJson(json));
      }
    }
    return models;
  }

  @override
  Future<void> delete(String id) async {
    await _storage.deleteValue(id);
  }

  @override
  Future<PdkPayjoinReceiverModel> processRequest({
    required String id,
    required FutureOr<bool> Function(Uint8List) hasOwnedInputs,
    required FutureOr<bool> Function(Uint8List) hasReceiverOutput,
    required List<PdkInputPairModel> inputPairs,
    required FutureOr<String> Function(String) processPsbt,
  }) async {
    final model = await get(id) as PdkPayjoinReceiverModel?;

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
            redeemScript: await Script.newInstance(
              rawOutputScript: input.redeemScriptRawOutputScript,
            ),
            witnessScript: await Script.newInstance(
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
      debugPrint(e.toString());
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
      isCompleted: true, // Nothing more to do from the receiver side
    );
    await _store(updatedModel);

    return updatedModel;
  }

  @override
  Future<PdkPayjoinSenderModel> completeSender(
    String uri, {
    required String txId,
  }) async {
    final model = await get(uri) as PdkPayjoinSenderModel?;

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

  Future<void> _store(PdkPayjoinModel model) async {
    final value = jsonEncode(model.toJson());
    if (model is PdkPayjoinReceiverModel) {
      await _storage.saveValue(key: model.id, value: value);
    } else if (model is PdkPayjoinSenderModel) {
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
        final model = PdkPayjoinReceiverModel.fromJson(message);
        // Store the model received from the isolate
        await _store(model);
        // Send it to the higher repository layers for processing
        _payjoinRequestedController.add(model);
      }
    });

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
        final model = PdkPayjoinSenderModel.fromJson(message);
        // Store the model received from the isolate
        await _store(model);
        // Send it to the higher repository layers for processing
        _proposalSentController.add(model);
      }
    });

    _sendersIsolate =
        await Isolate.spawn(_sendersIsolateEntryPoint, receivePort.sendPort);
  }

  static Future<void> _receiversIsolateEntryPoint(SendPort sendPort) async {
    debugPrint('[Isolate] Started _receiversIsolateEntryPoint');
    // Initialize core library in the isolate too for the native pdk library
    await core.init();

    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    final Map<String, PdkPayjoinReceiverModel> receiverModels = {};

    // Listen for and register new receivers sent from the main isolate
    receivePort.listen((data) async {
      debugPrint('Received data in receivers isolate: $data');
      final receiverModel =
          PdkPayjoinReceiverModel.fromJson(data as Map<String, dynamic>);
      receiverModels[receiverModel.id] = receiverModel;
    });

    final dio = Dio();
    Timer.periodic(
      const Duration(seconds: 5),
      (Timer timer) async {
        for (final receiverModel in receiverModels.values) {
          final id = receiverModel.id;
          final receiver = Receiver.fromJson(receiverModel.receiver);
          try {
            final request = await getRequest(receiver: receiver, dio: dio);
            if (request != null) {
              // The original tx bytes are needed in the main isolate for
              //  further processing so extract them here and pass them through
              //  the model
              final originalTxBytes =
                  await request.extractTxToScheduleBroadcast();
              final updatedModel = receiverModel.copyWith(
                receiver: receiver.toJson(),
                originalTxBytes: originalTxBytes,
              );
              final updatedModelJson = jsonEncode(updatedModel.toJson());

              // Notify the main isolate so it can be processed further
              sendPort.send(updatedModelJson);

              // Remove the receiver from the map
              receiverModels.remove(id);
            }
          } catch (e) {
            debugPrint(e.toString());
            continue;
          }
        }
      },
    );
  }

  static Future<void> _sendersIsolateEntryPoint(SendPort sendPort) async {
    // Initialize core library in the isolate too for the native pdk library
    await core.init();

    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    final Map<String, PdkPayjoinSenderModel> senderModels = {};
    final Map<String, V2GetContext> senderContexts = {};

    final dio = Dio();
    // Listen for and register new receivers sent from the main isolate
    receivePort.listen((data) async {
      final senderModel =
          PdkPayjoinSenderModel.fromJson(data as Map<String, dynamic>);
      senderModels[senderModel.uri] = senderModel;
      final sender = Sender.fromJson(senderModel.sender);
      final context = await PdkDataSourceImpl.request(sender: sender, dio: dio);
      senderContexts[senderModel.uri] = context;
    });

    Timer.periodic(
      const Duration(seconds: 5),
      (Timer timer) async {
        for (final senderEntry in senderModels.entries) {
          final uri = senderEntry.key;
          final senderModel = senderEntry.value;
          final context = senderContexts[uri]!;
          try {
            final proposalPsbt = await PdkDataSourceImpl.getProposalPsbt(
              context: context,
              dio: dio,
            );
            if (proposalPsbt != null) {
              // The proposal psbt is needed in the main isolate for
              //  further processing so send it through the model
              final updatedModel = senderModel.copyWith(
                proposalPsbt: proposalPsbt,
              );

              // Notify the main isolate so the payjoin can be processed further
              sendPort.send(updatedModel.toJson());

              // Remove the sender from the map
              senderModels.remove(uri);
              senderContexts.remove(uri);
            }
          } catch (e) {
            debugPrint(e.toString());
            continue;
          }
        }
      },
    );
  }

  static Future<UncheckedProposal?> getRequest({
    required Receiver receiver,
    required Dio dio,
  }) async {
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
    final (req, context) = await sender.extractV2(
      ohttpProxyUrl: await Url.fromStr(ohttpRelayUrl),
    );

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

  static Future<String?> getProposalPsbt(
      {required V2GetContext context, required Dio dio}) async {
    final (req, reqCtx) =
        await context.extractReq(ohttpRelay: await Url.fromStr(ohttpRelayUrl));

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
  }

  Future<void> _resumePayjoins() async {
    final models = await getAll();
    for (final model in models) {
      if (model.isCompleted || model.isExpired) {
        continue;
      }
      if (model is PdkPayjoinReceiverModel) {
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
        }
      } else if (model is PdkPayjoinSenderModel) {
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

class PdkPayjoinNotFoundException implements Exception {
  final String message;

  PdkPayjoinNotFoundException(this.message);
}

class ReceiveCreationException implements Exception {
  final String message;

  ReceiveCreationException(this.message);
}

class NoValidPayjoinBip21Exception implements Exception {
  final String message;

  NoValidPayjoinBip21Exception(this.message);
}
