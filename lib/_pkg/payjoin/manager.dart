import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:dio/dio.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:payjoin_flutter/src/generated/frb_generated.dart';
import 'package:payjoin_flutter/uri.dart' as pj_uri;

const List<String> _ohttpRelayUrls = [
  'https://pj.bobspacebkk.com',
  'https://ohttp.achow101.com',
];

class PayjoinManager {
  PayjoinManager(this._walletTx);
  final WalletTx _walletTx;
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

  Future<void> _cleanupSession(String sessionId) async {
    _activePollers[sessionId]?.kill();
    _activePollers.remove(sessionId);
    _activePorts[sessionId]?.close();
    _activePorts.remove(sessionId);
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
        return await getCtx.processResponse(
          response: getRes.data as List<int>,
          ohttpCtx: getReqCtx,
        );
      } catch (e) {
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
