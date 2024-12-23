import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/payjoin/event.dart';
import 'package:bb_mobile/_pkg/payjoin/storage.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:dio/dio.dart';
import 'package:payjoin_flutter/bitcoin_ffi.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/receive.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:payjoin_flutter/src/generated/frb_generated.dart';
import 'package:payjoin_flutter/uri.dart' as pj_uri;
import 'package:payjoin_flutter/uri.dart';

const List<String> _ohttpRelayUrls = [
  'https://pj.bobspacebkk.com',
  'https://ohttp.achow101.com',
];

const payjoinDirectoryUrl = 'https://payjo.in';

class PayjoinManager {
  PayjoinManager(this._walletTx, this._payjoinStorage);
  final WalletTx _walletTx;
  final PayjoinStorage _payjoinStorage;
  final Map<String, Isolate> _activePollers = {};
  final Map<String, ReceivePort> _activePorts = {};

  Future<Sender> initSender(
    String pjUriString,
    int networkFeesSatPerVb,
    String originalPsbt,
  ) async {
    try {
      // TODO this is a super ugly hack because of ugliness in the bip21 module.
      // Fix that and get rid of this.
      final pjSubstring = pjUriString.substring(pjUriString.indexOf('pj=') + 3);
      final capitalizedPjSubstring = pjSubstring.toUpperCase();
      final pjUriStringWithCapitalizedPj =
          pjUriString.substring(0, pjUriString.indexOf('pj=') + 3) +
              capitalizedPjSubstring;
      // This should already be done before letting payjoin be enabled for sending
      final pjUri = (await pj_uri.Uri.fromStr(pjUriStringWithCapitalizedPj))
          .checkPjSupported();
      final minFeeRateSatPerKwu = BigInt.from(networkFeesSatPerVb * 250);
      final senderBuilder = await SenderBuilder.fromPsbtAndUri(
        psbtBase64: originalPsbt,
        pjUri: pjUri,
      );
      final sender = await senderBuilder.buildRecommended(
        minFeeRate: minFeeRateSatPerKwu,
      );
      return sender;
    } catch (e) {
      throw Exception('Error initializing payjoin Sender: $e');
    }
  }

  Future<Err?> spawnNewSender({
    required bool isTestnet,
    required Sender sender,
    required Wallet wallet,
    required String pjUrl,
  }) async {
    final err = await _payjoinStorage.insertSenderSession(
      sender,
      pjUrl,
      wallet.id,
      isTestnet,
    );
    if (err != null) return err;
    return spawnSender(
      isTestnet: isTestnet,
      sender: sender,
      wallet: wallet,
    );
  }

  Future<Err?> spawnSender({
    required bool isTestnet,
    required Sender sender,
    required Wallet wallet,
  }) async {
    try {
      final completer = Completer<Err?>();
      final receivePort = ReceivePort();

      // TODO Create unique ID for this payjoin session
      const sessionId = 'TODO_SENDER_ENDPOINT';

      receivePort.listen((message) async {
        print('Sender isolate: $message');
        if (message is Map<String, dynamic>) {
          if (message['type'] == 'psbt_to_sign') {
            final proposalPsbt = message['psbt'] as String;
            final (wtxid, err) = await _walletTx.signAndBroadcastPsbt(
              psbt: proposalPsbt,
              wallet: wallet,
            );
            if (err != null) {
              completer.complete(err);
              return;
            }
            PayjoinEventBus().emit(
              PayjoinBroadcastEvent(
                txid: wtxid!.$2,
              ),
            );
            await _cleanupSession(sessionId);
          } else if (message is Err) {
            // TODO propagate this error to the UI
            await _cleanupSession(sessionId);
          }
        }
      });

      final args = [
        receivePort.sendPort,
        sender.toJson(),
      ];

      final isolate = await Isolate.spawn(
        _isolateSender,
        args,
      );
      _activePollers[sessionId] = isolate;
      _activePorts[sessionId] = receivePort;
      return completer.future;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<Receiver> initReceiver(bool isTestnet, String address) async {
    try {
      final payjoinDirectory = await Url.fromStr(payjoinDirectoryUrl);
      final ohttpKeys = await fetchOhttpKeys(
        ohttpRelay: await _randomOhttpRelayUrl(),
        payjoinDirectory: payjoinDirectory,
      );
      return await Receiver.create(
        address: address,
        network: isTestnet ? Network.testnet : Network.bitcoin,
        directory: payjoinDirectory,
        ohttpKeys: ohttpKeys,
        ohttpRelay: await _randomOhttpRelayUrl(),
      );
    } catch (e) {
      throw Exception('Error initializing payjoin Receiver: $e');
    }
  }

  Future<Err?> spawnNewReceiver({
    required bool isTestnet,
    required Receiver receiver,
    required Wallet wallet,
  }) async {
    final err = await _payjoinStorage.insertReceiverSession(
      isTestnet,
      receiver,
      wallet.id,
    );
    if (err != null) return err;
    return spawnReceiver(
      isTestnet: isTestnet,
      receiver: receiver,
      wallet: wallet,
    );
  }

  Future<Err?> spawnReceiver({
    required bool isTestnet,
    required Receiver receiver,
    required Wallet wallet,
  }) async {
    try {
      final completer = Completer<Err?>();
      final receivePort = ReceivePort();
      SendPort? mainToIsolateSendPort;

      receivePort.listen((message) async {
        print('Receiver isolate: $message');
        if (message is Map<String, dynamic>) {
          try {
            switch (message['type']) {
              case 'init':
                mainToIsolateSendPort = message['port'] as SendPort;

              case 'check_is_owned':
                final inputScript = message['input_script'] as Uint8List;
                final isOwned = await _checkIsOwned(
                  inputScript: inputScript,
                  isTestnet: isTestnet,
                  wallet: wallet,
                );
                mainToIsolateSendPort?.send({
                  'requestId': message['requestId'],
                  'result': isOwned,
                });

              case 'check_is_receiver_output':
                final outputScript = message['output_script'] as Uint8List;
                final isReceiverOutput = await _checkIsOwned(
                  inputScript: outputScript,
                  isTestnet: isTestnet,
                  wallet: wallet,
                );
                mainToIsolateSendPort?.send({
                  'requestId': message['requestId'],
                  'result': isReceiverOutput,
                });

              case 'get_candidate_inputs':
                final inputs = await _walletTx.listUnspent(wallet: wallet);
                mainToIsolateSendPort?.send({
                  'requestId': message['requestId'],
                  'result': inputs,
                });

              case 'process_psbt':
                final psbt = message['psbt'] as String;
                final signedPsbt =
                    await _processPsbt(psbt: psbt, wallet: wallet);
                mainToIsolateSendPort?.send({
                  'requestId': message['requestId'],
                  'result': signedPsbt,
                });
            }
          } catch (e) {
            // TODO PROPAGATE ERROR TO UI TOAST / TRANSACTION HISTORY
          }
        }
      });

      final args = [
        receivePort.sendPort,
        receiver.toJson(),
      ];

      final isolate = await Isolate.spawn(
        _isolateReceiver,
        args,
      );

      _activePollers[receiver.id()] = isolate;
      _activePorts[receiver.id()] = receivePort;

      return completer.future;
    } catch (e) {
      return Err(
        e.toString(),
        title: 'Error occurred while receiving Payjoin',
        solution: 'Please try again.',
      );
    }
  }

  Future<void> resumeSessions(Wallet wallet) async {
    // Retrieve stored sessions and spawn them
    // You can implement your own logic for loading sessions
    final (receiverSessions, receiverErr) =
        await _payjoinStorage.readAllReceivers();

    final filteredReceivers = receiverSessions
        .where((session) => session.walletId == wallet.id)
        .toList();

    if (receiverErr != null) throw receiverErr;
    for (final session in filteredReceivers) {
      await spawnReceiver(
        isTestnet: session.isTestnet,
        receiver: session.receiver,
        wallet: wallet,
      );
    }

    final (senderSessions, senderErr) = await _payjoinStorage.readAllSenders();
    final filteredSenders = senderSessions.where((session) {
      return session.walletId == wallet.id;
    }).toList();
    if (senderErr != null) throw senderErr;
    for (final session in filteredSenders) {
      await spawnSender(
        isTestnet: session.isTestnet,
        sender: session.sender,
        wallet: wallet,
      );
    }
  }

  void pauseAllSessions() {
    // Cleanup all active sessions
    for (final sessionId in _activePollers.keys.toList()) {
      _cleanupSession(sessionId);
    }
  }

  Future<bool> _checkIsOwned({
    required Uint8List inputScript,
    required bool isTestnet,
    required Wallet wallet,
  }) async {
    return await _walletTx.isMine(
      inputScript: inputScript,
      wallet: wallet,
    );
  }

  Future<List<bdk.LocalUtxo>> _listUnspent(
    Wallet wallet,
    bool isTestnet,
  ) async {
    return await _walletTx.listUnspent(wallet: wallet);
  }

  Future<String> _processPsbt({
    required String psbt,
    required Wallet wallet,
  }) async {
    final (signed, err) = await _walletTx.signPsbt(
      psbt: psbt,
      wallet: wallet,
    );
    if (err != null) throw err;
    final signedPsbt = signed!.$2;
    return signedPsbt;
  }

  Future<void> _cleanupSession(String sessionId) async {
    _activePollers[sessionId]?.kill();
    _activePollers.remove(sessionId);
    _activePorts[sessionId]?.close();
    _activePorts.remove(sessionId);
  }
}

class SendSession {
  SendSession(this._isTestnet, this._sender, this._walletId, this._pjUri);

  // Deserialize JSON to Receiver
  factory SendSession.fromJson(Map<String, dynamic> json) {
    return SendSession(
      json['isTestnet'] as bool,
      Sender.fromJson(json['sender'] as String),
      json['walletId'] as String,
      json['pjUri'] as String,
    );
  }

  final bool _isTestnet;
  final Sender _sender;
  final String _walletId;
  final String _pjUri;

  bool get isTestnet => _isTestnet;
  Sender get sender => _sender;
  String get walletId => _walletId;
  String get pjUri => _pjUri;

  // Serialize Receiver to JSON
  Map<String, dynamic> toJson() {
    return {
      'isTestnet': _isTestnet,
      'sender': _sender.toJson(),
      'walletId': _walletId,
      'pjUri': _pjUri,
    };
  }
}

class RecvSession {
  RecvSession(this._isTestnet, this._receiver, this._walletId);

  factory RecvSession.fromJson(Map<String, dynamic> json) {
    return RecvSession(
      json['isTestnet'] as bool,
      Receiver.fromJson(json['receiver'] as String),
      json['walletId'] as String,
    );
  }

  final bool _isTestnet;
  final Receiver _receiver;
  final String _walletId;

  bool get isTestnet => _isTestnet;
  Receiver get receiver => _receiver;
  String get walletId => _walletId;

  Map<String, dynamic> toJson() {
    return {
      'isTestnet': isTestnet,
      'receiver': receiver.toJson(),
      'walletId': walletId,
    };
  }
}

// Top-level function to generate random OHTTP relay URL
Future<pj_uri.Url> _randomOhttpRelayUrl() async {
  return await pj_uri.Url.fromStr(
    _ohttpRelayUrls[Random.secure().nextInt(_ohttpRelayUrls.length)],
  );
}

/// Top-level function that runs inside the isolate.
/// It should not reference instance-specific variables or methods.
Future<void> _isolateSender(List<dynamic> args) async {
  // Initialize any core dependencies here if required
  await core.init();

  final sendPort = args[0] as SendPort;
  final senderJson = args[1] as String;

  // Reconstruct the Sender from the JSON
  final sender = Sender.fromJson(senderJson);

  // Run the sender logic inside the isolate
  try {
    final proposalPsbt = await _runSender(sender);
    if (proposalPsbt == null) throw Exception('proposalPsbt is null');
    sendPort.send({
      'type': 'psbt_to_sign',
      'psbt': proposalPsbt,
    });
  } catch (e) {
    sendPort.send(Err(e.toString()));
  }
}

/// Top-level function that attempts to run payjoin sender (V2 protocol first, fallback to V1).
Future<String?> _runSender(Sender sender) async {
  final dio = Dio();

  try {
    final result = await sender.extractV2(
      ohttpProxyUrl: await _randomOhttpRelayUrl(),
    );
    final postReq = result.$1;
    final postReqCtx = result.$2;

    // Attempt V2
    final postRes = await _postRequest(dio, postReq);
    final getCtx = await postReqCtx.processResponse(
      response: postRes.data as List<int>,
    );

    while (true) {
      try {
        final (getRequest, getReqCtx) = await getCtx.extractReq(
          ohttpRelay: await _randomOhttpRelayUrl(),
        );
        final getRes = await _postRequest(dio, getRequest);
        final proposalPsbt = await getCtx.processResponse(
          response: getRes.data as List<int>,
          ohttpCtx: getReqCtx,
        );
        if (proposalPsbt != null) return proposalPsbt;
      } catch (e) {
        print('Error occurred while processing payjoin: $e');
        // Loop until a valid response is found
      }
    }
  } catch (e) {
    // If V2 fails, attempt V1
    return await _runSenderV1(sender, dio);
  }
}

/// Attempt to send payjoin using the V1 protocol.
Future<String> _runSenderV1(Sender sender, Dio dio) async {
  try {
    final (req, v1Ctx) = await sender.extractV1();
    final response = await _postRequest(dio, req);
    final proposalPsbt =
        await v1Ctx.processResponse(response: response.data as List<int>);
    return proposalPsbt;
  } catch (e) {
    throw Exception('Send V1 payjoin error: $e');
  }
}

Future<void> _isolateReceiver(List<dynamic> args) async {
  await core.init();
  final isolateTomainSendPort = args[0] as SendPort;
  final receiver = Receiver.fromJson(args[1] as String);

  final isolateReceivePort = ReceivePort();
  isolateTomainSendPort
      .send({'type': 'init', 'port': isolateReceivePort.sendPort});
  final pendingRequests = <String, Completer<dynamic>>{};
  // Listen for responses from the main isolate
  isolateReceivePort.listen((message) {
    if (message is Map<String, dynamic>) {
      final requestId = message['requestId'] as String?;
      if (requestId != null && pendingRequests.containsKey(requestId)) {
        pendingRequests[requestId]!.complete(message['result']);
        pendingRequests.remove(requestId);
      }
    }
  });

  // Define sendAndWait with access to necessary ports
  Future<dynamic> sendAndWait(
    String type,
    Map<String, dynamic> data,
    SendPort isolateToMainSendPort,
  ) async {
    final completer = Completer<dynamic>();
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    pendingRequests[requestId] = completer;

    isolateToMainSendPort.send({
      ...data,
      'type': type,
      'requestId': requestId,
    });

    return completer.future;
  }

  Future<PayjoinProposal> processPayjoinProposal(
    UncheckedProposal proposal,
    SendPort sendPort,
    ReceivePort receivePort,
  ) async {
    final fallbackTx = await proposal.extractTxToScheduleBroadcast();
    // TODO Handle this. send to the main port on a timer?

    try {
      // Receive Check 1: can broadcast
      final pj1 = await proposal.assumeInteractiveReceiver();
      // Receive Check 2: original PSBT has no receiver-owned inputs
      final pj2 = await pj1.checkInputsNotOwned(
        isOwned: (inputScript) async {
          final result = await sendAndWait(
            'check_is_owned',
            {'input_script': inputScript},
            sendPort,
          );
          return result as bool;
        },
      );
      // Receive Check 3: sender inputs have not been seen before (prevent probing attacks)
      final pj3 = await pj2.checkNoInputsSeenBefore(
        isKnown: (input) {
          // TODO: keep track of seen inputs in hive storage?
          return false;
        },
      );

      // Identify receiver outputs
      final pj4 = await pj3.identifyReceiverOutputs(
        isReceiverOutput: (outputScript) async {
          final result = await sendAndWait(
            'check_is_receiver_output',
            {'output_script': outputScript},
            sendPort,
          );
          return result as bool;
        },
      );
      final pj5 = await pj4.commitOutputs();

      final listUnspent = await sendAndWait(
        'get_candidate_inputs',
        {},
        sendPort,
      );
      final unspent = listUnspent as List<bdk.LocalUtxo>;
      final candidateInputs = await Future.wait(
        unspent.map((utxo) => _inputPairFromUtxo(utxo, true)),
      );
      final selectedUtxo = await pj5.tryPreservingPrivacy(
        candidateInputs: candidateInputs,
      );
      final pj6 = await pj5.contributeInputs(replacementInputs: [selectedUtxo]);
      final pj7 = await pj6.commitInputs();

      // Finalize proposal
      final payjoinProposal = await pj7.finalizeProposal(
        processPsbt: (String psbt) async {
          final result = await sendAndWait(
            'process_psbt',
            {'psbt': psbt},
            sendPort,
          );
          return result as String;
        },
        // TODO set maxFeeRateSatPerVb
        maxFeeRateSatPerVb: BigInt.from(10000),
      );
      return payjoinProposal;
    } catch (e) {
      print('Error occurred while finalizing proposal: $e');
      throw Exception('Error occurred while finalizing proposal');
    }
  }

  try {
    final dio = Dio();
    final uncheckedProposal = await _receiveUncheckedProposal(dio, receiver);
    final payjoinProposal = await processPayjoinProposal(
      uncheckedProposal,
      isolateTomainSendPort,
      isolateReceivePort,
    );
    _respondProposal(dio, payjoinProposal);
  } catch (e) {
    isolateTomainSendPort.send(Err(e.toString()));
  }
}

Future<UncheckedProposal> _receiveUncheckedProposal(
  Dio dio,
  Receiver receiver,
) async {
  try {
    while (true) {
      final (req, context) = await receiver.extractReq();
      final ohttpResponse = await _postRequest(dio, req);
      final proposal = await receiver.processRes(
        body: ohttpResponse.data as List<int>,
        ctx: context,
      );
      if (proposal != null) {
        return proposal;
      }
    }
  } catch (e) {
    throw Exception('Error occurred while processing payjoin receiver: $e');
  }
}

Future<void> _respondProposal(Dio dio, PayjoinProposal proposal) async {
  try {
    final (postReq, ohttpCtx) = await proposal.extractV2Req();
    final postRes = await _postRequest(dio, postReq);
    await proposal.processRes(
      res: postRes.data as List<int>,
      ohttpContext: ohttpCtx,
    );
  } catch (e) {
    throw Exception('Error occurred while processing payjoin: $e');
  }
}

/// Posts a request via dio and returns the response.
Future<Response<dynamic>> _postRequest(Dio dio, Request req) async {
  return await dio.post(
    req.url.asString(),
    options: Options(
      headers: {
        'Content-Type': req.contentType,
      },
      responseType: ResponseType.bytes,
    ),
    data: req.body,
  );
}

Future<InputPair> _inputPairFromUtxo(bdk.LocalUtxo utxo, bool isTestnet) async {
  final psbtin = PsbtInput(
    // We should be able to merge these bdk & payjoin rust-bitcoin types with bitcoin-ffi eventually
    witnessUtxo: TxOut(
      value: utxo.txout.value,
      scriptPubkey: utxo.txout.scriptPubkey.bytes,
    ),
    // TODO: redeem script/witness script?
  );
  final txin = TxIn(
    previousOutput:
        OutPoint(txid: utxo.outpoint.txid, vout: utxo.outpoint.vout),
    scriptSig: await Script.newInstance(rawOutputScript: []),
    sequence: 0xFFFFFFFF,
    witness: [],
  );
  return InputPair.newInstance(txin, psbtin);
}
