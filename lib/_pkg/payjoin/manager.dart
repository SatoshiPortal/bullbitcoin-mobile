import 'dart:isolate';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/payjoin/session_storage.dart';
import 'package:bb_mobile/_pkg/payjoin/sync.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:http/http.dart' as http;
import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:payjoin_flutter/uri.dart' as pj_uri;

class PayjoinManager {
  PayjoinManager(this._sessionStorage, this._walletTx);
  final PayjoinSessionStorage _sessionStorage;
  final WalletTx _walletTx;

  Future<void> syncAllSessions(
    bdk.Wallet wallet,
    bdk.Blockchain blockchain,
  ) async {
    // Retrieve and sync all receiver sessions
    final (receivers, err) = await _sessionStorage.readAllReceivers();
    if (err != null) return; // Handle error

    for (final receiver in receivers) {
      await PayjoinSync().spawnReceiver(receiver: receiver);
    }

    // Retrieve and sync all sender sessions
    final (senders, err2) = await _sessionStorage.readAllSenders();
    if (err2 != null) return; // Handle error

    for (final sender in senders) {
      await spawnSender(sender, wallet, blockchain);
    }
  }

  Future<void> spawnSender(
    Sender sender,
    bdk.Wallet wallet,
    bdk.Blockchain blockchain,
  ) async {
    final receivePort = ReceivePort();
    Isolate.spawn(
      _isolateSender,
      [receivePort.sendPort, sender.toJson(), wallet, blockchain, _walletTx],
    );

    receivePort.listen((message) {
      // Handle messages from the isolate
    });
  }

  static Future<void> _isolateSender(List<dynamic> args) async {
    final sendPort = args[0] as SendPort;
    final sender = Sender.fromJson(args[1] as String);
    final bdkWallet = args[2] as bdk.Wallet;
    final blockchain = args[3] as bdk.Blockchain;

    // Process the sender and sign the transaction
    final proposal = await pollSender(sender);

    // SIGN AND BROADCAST ---------------------------
    try {
      final psbtStruct =
          await bdk.PartiallySignedTransaction.fromString(proposal!);
      await bdkWallet.sign(
        psbt: psbtStruct,
        signOptions: const bdk.SignOptions(
          trustWitnessUtxo: false,
          allowAllSighashes: false,
          removePartialSigs: true,
          tryFinalize: true,
          signWithTapInternalKey: false,
          allowGrinding: true,
        ),
      );

      final finalizedTx = psbtStruct.extractTx();
      final signedPsbt = psbtStruct.toString();

      // Broadcast the transaction
      final broadcastedTx =
          await blockchain.broadcast(transaction: finalizedTx);
      print('Broadcasted transaction: $broadcastedTx');

      // Send success message back to the main isolate
      sendPort.send(broadcastedTx);
    } catch (e) {
      sendPort.send(
        Err(
          e.toString(),
          title: 'Error occurred while signing and broadcasting transaction',
          solution: 'Please try again.',
        ),
      );
    }
  }
}

Future<String?> pollSender(Sender sender) async {
  final ohttpProxyUrl = await pj_uri.Url.fromStr('https://ohttp.achow101.com');
  Request postReq;
  V2PostContext postReqCtx;
  try {
    final result = await sender.extractV2(ohttpProxyUrl: ohttpProxyUrl);
    postReq = result.$1;
    postReqCtx = result.$2;
  } catch (e) {
    try {
      final (req, v1Ctx) = await sender.extractV1();
      print('Posting Original PSBT Payload request...');
      final response = await http.post(
        Uri.parse(req.url.asString()),
        headers: {
          'Content-Type': req.contentType,
        },
        body: req.body,
      );
      print('Sent fallback transaction');
      final proposalPsbt =
          await v1Ctx.processResponse(response: response.bodyBytes);
      return proposalPsbt;
    } catch (e) {
      print(e);
      throw Exception('Response error: $e');
    }
  }
  final postRes = await http.post(
    Uri.parse(postReq.url.asString()),
    headers: {
      'Content-Type': postReq.contentType,
    },
    body: postReq.body,
  );
  final getCtx = await postReqCtx.processResponse(
    response: postRes.bodyBytes,
  );
  String? proposalPsbt;
  while (true) {
    final (getRequest, getReqCtx) = await getCtx.extractReq(
      ohttpRelay: ohttpProxyUrl,
    );
    final getRes = await http.post(
      Uri.parse(getRequest.url.asString()),
      headers: {
        'Content-Type': getRequest.contentType,
      },
      body: getRequest.body,
    );
    proposalPsbt = await getCtx.processResponse(
      response: getRes.bodyBytes,
      ohttpCtx: getReqCtx,
    ); // TODO throw error if null
    break;
  }
  return proposalPsbt;
}
