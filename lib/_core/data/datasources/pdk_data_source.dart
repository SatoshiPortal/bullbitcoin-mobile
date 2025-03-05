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
  // requestedPayjoins is a stream that emits a PdkPayjoinReceiverModel every
  //  time a payjoin request (original tx psbt) is received from a sender.
  Stream<PdkPayjoinReceiverModel> get requestedPayjoins;
  // sentProposals is a stream that emits a PdkPayjoinSenderModel every time a
  //  payjoin proposal (payjoin tx psbt) was sent by a receiver.
  Stream<PdkPayjoinSenderModel> get sentProposals;
  Future<PdkPayjoinReceiverModel> createReceiver({
    required String walletId,
    required String address,
    required bool isTestnet,
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
    required bool originalTxHasOwnedInputs,
    bool originalTxHasSeenInputs = false,
    required bool originalTxHasReceiverOutput,
    required List<PdkInputPairModel> inputPairs,
    required BigInt maxFeeRateSatPerVb,
    required FutureOr<String> Function(String) processPsbt,
  });
}

class PdkDataSourceImpl implements PdkDataSource {
  final String _ohttpRelayUrl;
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
  final Duration _pollingInterval = const Duration(seconds: 5);

  PdkDataSourceImpl({
    String ohttpRelayUrl = 'https://pj.bobspacebkk.com',
    String payjoinDirectoryUrl = 'https://payjo.in',
    required Dio dio,
    required KeyValueStorageDataSource<String> storage,
  })  : _ohttpRelayUrl = ohttpRelayUrl,
        _payjoinDirectoryUrl = payjoinDirectoryUrl,
        _dio = dio,
        _storage = storage {
    _resumePayjoins();
  }

  @override
  Stream<PdkPayjoinReceiverModel> get requestedPayjoins =>
      _payjoinRequestedController.stream.asBroadcastStream();

  @override
  Stream<PdkPayjoinSenderModel> get sentProposals =>
      _proposalSentController.stream.asBroadcastStream();

  @override
  Future<PdkPayjoinReceiverModel> createReceiver({
    required String walletId,
    required String address,
    required bool isTestnet,
    int? expireAfterSec,
  }) async {
    try {
      final payjoinDirectory = await Url.fromStr(_payjoinDirectoryUrl);
      final ohttpRelay = await Url.fromStr(_ohttpRelayUrl);
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

      final pjUrl = await receiver.pjUrl();
      final receiverJson = receiver.toJson();

      // Start listening for a payjoin request from the sender in an isolate
      if (_receiversIsolate == null) {
        await _startReceiversIsolate();
      }
      // We can just send the pdk receiver json, since it contains the id and
      //  so everything we need to obtain the model as well.
      _receiversIsolatePort?.send(receiverJson);

      // Create and store the model to keep track of the payjoin session
      final model = PdkPayjoinModel.receive(
        id: receiver.id(),
        receiver: receiverJson,
        walletId: walletId,
        pjUrl: pjUrl.asString(),
      ) as PdkPayjoinReceiverModel;
      await _store(model);

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
    final model = PdkPayjoinModel.send(
      uri: uri.asString(),
      sender: senderJson,
      walletId: walletId,
      originalPsbt: originalPsbt,
    ) as PdkPayjoinSenderModel;
    await _store(model);

    // Start listening for a payjoin proposal from the receiver in an isolate
    if (_sendersIsolate == null) {
      await _startSendersIsolate();
    }
    // We should send the PdkPayjoinSenderModel json to the senders isolate,
    //  since just the pdk sender json does not contain the uri to identify
    //  the payjoin and retrieve the model
    final modelJson = jsonEncode(model.toJson());
    _sendersIsolatePort?.send(modelJson);

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
    required bool originalTxHasOwnedInputs,
    bool originalTxHasSeenInputs = false,
    required bool originalTxHasReceiverOutput,
    required List<PdkInputPairModel> inputPairs,
    required BigInt maxFeeRateSatPerVb,
    required FutureOr<String> Function(String) processPsbt,
  }) async {
    final model = await get(id) as PdkPayjoinReceiverModel?;

    if (model == null) {
      throw Exception('No model found');
    }

    final receiver = Receiver.fromJson(model.receiver);
    final request = await _getRequest(receiver: receiver);

    if (request == null) {
      throw Exception('No request found');
    }

    final interactiveReceiver = await request.assumeInteractiveReceiver();
    final inputsNotOwned = await interactiveReceiver.checkInputsNotOwned(
      isOwned: (_) => originalTxHasOwnedInputs,
    );
    final inputsNotSeen = await inputsNotOwned.checkNoInputsSeenBefore(
      isKnown: (_) => originalTxHasSeenInputs,
    );
    final receiverOutputs = await inputsNotSeen.identifyReceiverOutputs(
      isReceiverOutput: (_) => originalTxHasReceiverOutput,
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
      maxFeeRateSatPerVb: maxFeeRateSatPerVb,
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
  Future<void> _startReceiversIsolate() async {
    // Receive isolate
    final receivePort = ReceivePort();
    _receiversIsolate =
        await Isolate.spawn(_receiversIsolateEntryPoint, receivePort.sendPort);
    _receiversIsolatePort = await receivePort.first as SendPort;

    // Listen for payjoin requests from the receive isolate
    receivePort.listen((data) async {
      final id = data as String;
      final model = await get(id);
      if (model != null) {
        _payjoinRequestedController.add(model as PdkPayjoinReceiverModel);
      }
    });
  }

  /// Starts the isolate to request and listen for payjoin proposals.
  Future<void> _startSendersIsolate() async {
    // Senders isolate
    final receivePort = ReceivePort();
    _sendersIsolate =
        await Isolate.spawn(_sendersIsolateEntryPoint, receivePort.sendPort);
    _sendersIsolatePort = await receivePort.first as SendPort;

    // Listen for payjoin proposals from the senders isolate
    receivePort.listen((data) async {
      final uri = data as String;
      final model = await get(uri);
      if (model != null) {
        _proposalSentController.add(model as PdkPayjoinSenderModel);
      }
    });
  }

  Future<void> _receiversIsolateEntryPoint(SendPort sendPort) async {
    // Initialize core library in the isolate too for the native pdk library
    await core.init();

    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    final Map<String, Receiver> receivers = {};

    // Listen for and register new receivers sent from the main isolate
    receivePort.listen((data) async {
      final receiverJson = data as String;
      final receiver = Receiver.fromJson(receiverJson);
      receivers[receiver.id()] = receiver;
    });

    Timer.periodic(
      _pollingInterval,
      (Timer timer) async {
        for (final receiver in receivers.values) {
          final id = receiver.id();
          try {
            final request = await _getRequest(receiver: receiver);
            if (request != null) {
              final model = await get(id) as PdkPayjoinReceiverModel?;
              if (model == null) {
                throw PdkPayjoinNotFoundException(
                  'Payjoin receiver with id $id not found',
                );
              }

              // The original tx bytes are needed in the main isolate for
              //  further processing so extract them here and store them through
              //  the model
              final originalTxBytes =
                  await request.extractTxToScheduleBroadcast();
              final updatedModel = model.copyWith(
                receiver: receiver.toJson(),
                originalTxBytes: originalTxBytes,
              );
              await _store(updatedModel);

              // Notify the main isolate so it can be processed further
              sendPort.send(id);

              // Remove the receiver from the map
              receivers.remove(id);
            }
          } catch (e) {
            debugPrint(e.toString());
            continue;
          }
        }
      },
    );
  }

  Future<void> _sendersIsolateEntryPoint(SendPort sendPort) async {
    // Initialize core library in the isolate too for the native pdk library
    await core.init();

    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    final Map<String, V2GetContext> senderContexts = {};

    // Listen for and register new receivers sent from the main isolate
    receivePort.listen((data) async {
      final senderModelJson =
          jsonDecode(data as String) as Map<String, dynamic>;
      final senderModel = PdkPayjoinSenderModel.fromJson(senderModelJson);
      final sender = Sender.fromJson(senderModel.sender);
      final context = await _request(sender: sender);
      senderContexts[senderModel.uri] = context;
    });

    Timer.periodic(
      _pollingInterval,
      (Timer timer) async {
        for (final entry in senderContexts.entries) {
          final uri = entry.key;
          final context = entry.value;
          try {
            final proposalPsbt = await _getProposalPsbt(context: context);
            if (proposalPsbt != null) {
              final model = await get(uri) as PdkPayjoinSenderModel?;
              if (model == null) {
                throw PdkPayjoinNotFoundException(
                  'Payjoin sender for uri $uri not found',
                );
              }

              // The proposal psbt is needed in the main isolate for
              //  further processing so store it in the model
              final updatedModel = model.copyWith(
                proposalPsbt: proposalPsbt,
              );
              await _store(updatedModel);

              // Notify the main isolate so the payjoin can be processed further
              sendPort.send(uri);

              // Remove the sender from the map
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

  Future<UncheckedProposal?> _getRequest({
    required Receiver receiver,
  }) async {
    final (req, context) = await receiver.extractReq();
    final ohttpResponse = await _dio.post(
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

  Future<V2GetContext> _request({
    required Sender sender,
  }) async {
    final (req, context) = await sender.extractV2(
      ohttpProxyUrl: await Url.fromStr(_ohttpRelayUrl),
    );

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

    final getCtx = await context.processResponse(
      response: res.data as List<int>,
    );

    return getCtx;
  }

  Future<String?> _getProposalPsbt({required V2GetContext context}) async {
    final (req, reqCtx) =
        await context.extractReq(ohttpRelay: await Url.fromStr(_ohttpRelayUrl));

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

    final proposalPsbt = await context.processResponse(
      response: res.data as List<int>,
      ohttpCtx: reqCtx,
    );

    return proposalPsbt;
  }

  Future<void> _resumePayjoins() async {
    final models = await getAll();
    for (final model in models) {
      if (model is PdkPayjoinReceiverModel) {
        if (model.originalTxBytes == null) {
          // If the original tx bytes are not present, it means the receiver
          //  needs to listen for a payjoin request from the sender, we do this
          //  in the isolate.
          if (_receiversIsolate == null) {
            // Start the isolate if it is not running yet
            await _startReceiversIsolate();
          }
          _receiversIsolatePort?.send(model.receiver);
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
            await _startSendersIsolate();
          }
          final modelJson = jsonEncode(model.toJson());
          _sendersIsolatePort?.send(modelJson);
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
