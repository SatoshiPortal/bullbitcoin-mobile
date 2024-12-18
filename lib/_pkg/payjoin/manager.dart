import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';

import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:http/http.dart' as http;
import 'package:payjoin_flutter/bitcoin_ffi.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/receive.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:payjoin_flutter/src/generated/frb_generated.dart';
import 'package:payjoin_flutter/uri.dart' as pj_uri;

class PayjoinManager {
  PayjoinManager(this._networkCubit, this._walletTx);
  final NetworkCubit _networkCubit;
  final WalletTx _walletTx;
  final Map<String, Isolate> _activePollers = {};
  final Map<String, ReceivePort> _activePorts = {};

  Future<bdk.Blockchain> blockchain(bool isTestnet) async {
    final network = _networkCubit.state.getNetwork();
    final url = isTestnet ? network?.testnet : network?.mainnet;
    final retry = network?.retry;
    final timeout = network?.timeout;
    final stopGap = network?.stopGap;
    final validateDomain = network?.validateDomain;
    return await bdk.Blockchain.create(
      config: bdk.BlockchainConfig.electrum(
        config: bdk.ElectrumConfig(
          url: url!,
          retry: retry!,
          timeout: timeout!,
          stopGap: BigInt.from(stopGap!),
          validateDomain: validateDomain!,
        ),
      ),
    );
  }

  // Future<void> syncAllSessions(
  //   bdk.Blockchain blockchain,
  // ) async {
  //   // Retrieve and sync all receiver sessions
  //   final (receivers, err) = await _sessionStorage.readAllReceivers();
  //   if (err != null) return; // Handle error

  //   for (final receiver in receivers) {
  //     await spawnReceiver(
  //       receiver: receiver,
  //       wallet: wallet,
  //       blockchain: blockchain,
  //     );
  //   }

  //   // Retrieve and sync all sender sessions
  //   final (senders, err2) = await _sessionStorage.readAllSenders();
  //   if (err2 != null) return; // Handle error

  //   for (final sender in senders) {
  //     await spawnSender(sender, wallet, blockchain);
  //   }
  // }

  Future<Err?> spawnReceiver({
    required bool isTestnet,
    required Receiver receiver,
    required Wallet wallet,
  }) async {
    print('spawnReceiver: $receiver');
    try {
      final completer = Completer<Err?>();
      final receivePort = ReceivePort();
      SendPort? mainToIsolateSendPort;

      receivePort.listen((message) async {
        if (message is Map<String, dynamic>) {
          switch (message['type']) {
            case 'init':
              print('init case');
              mainToIsolateSendPort = message['port'] as SendPort;

            case 'check_is_owned':
              try {
                print('check_is_owned case');
                final inputScript = message['input_script'] as Uint8List;
                print('inputScript: $inputScript');
                final isOwned = await checkIsOwned(
                  inputScript: inputScript,
                  isTestnet: isTestnet,
                  wallet: wallet,
                );
                print('exists: $isOwned');
                print('isolateToMainSendPort: $mainToIsolateSendPort');
                mainToIsolateSendPort?.send({
                  'requestId': message['requestId'],
                  'result': isOwned,
                });
              } catch (e) {
                rethrow;
              }

            case 'check_is_receiver_output':
              try {
                final outputScript = message['output_script'] as Uint8List;
                final isReceiverOutput = await checkIsReceiverOutput(
                  outputScript: outputScript,
                  isTestnet: isTestnet,
                  wallet: wallet,
                );
                print('exists: $isReceiverOutput');
                print('isolateToMainSendPort: $mainToIsolateSendPort');
                mainToIsolateSendPort?.send({
                  'requestId': message['requestId'],
                  'result': isReceiverOutput,
                });
              } catch (e) {
                rethrow;
              }

            case 'get_candidate_inputs':
              try {
                final inputs = await getCandidateInputs(
                  wallet: wallet,
                  isTestnet: isTestnet,
                );
                print('inputs: $inputs');
                mainToIsolateSendPort?.send({
                  'requestId': message['requestId'],
                  'result': inputs,
                });
              } catch (e) {
                print('err: $e');
                rethrow;
              }

            case 'check_address':
              try {
                final address = message['address'] as String;
                final exists =
                    await _walletTx.addressExistsInWallet(address, wallet);
                mainToIsolateSendPort?.send({
                  'type': 'address_check_result',
                  'requestId': message['requestId'],
                  'exists': exists,
                });
              } catch (e) {
                mainToIsolateSendPort?.send({
                  'type': 'error',
                  'error': e.toString(),
                });
              }

            case 'process_psbt':
              try {
                final psbt = message['psbt'] as String;
                print('process_psbt: $psbt');
                final signedPsbt =
                    await processPsbt(psbt: psbt, wallet: wallet);
                print('signedPsbt: $signedPsbt');
                mainToIsolateSendPort?.send({
                  'requestId': message['requestId'],
                  'result': signedPsbt,
                });
              } catch (e) {
                print('err: $e');
                rethrow;
              }
              break;
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
      print('err: $e');
      return Err(
        e.toString(),
        title: 'Error occurred while receiving Payjoin',
        solution: 'Please try again.',
      );
    }
  }

  Future<Err?> spawnSender({
    required bool isTestnet,
    required Sender sender,
    required Wallet wallet,
  }) async {
    print('spawnSender');
    try {
      final completer = Completer<Err?>();
      final receivePort = ReceivePort();
      final senderJson = sender.toJson();
      print('isolateSender: $senderJson');

      // Create unique ID for this payjoin session
      final sessionId = 'TODO_SENDER_ENDPOINT';

      receivePort.listen((message) async {
        print('spawnSenderreceivePort message: $message');
        if (message is Map<String, dynamic>) {
          print(
              'spawnSenderreceivePort message is Map<String, dynamic>: $message');
          if (message['type'] == 'psbt_to_sign') {
            print('spawnSenderreceivePort message type is psbt_to_sign');
            final proposalPsbt = message['psbt'] as String;
            final (result, err) = await _walletTx.signPsbt(
              psbt: proposalPsbt,
              wallet: wallet,
            );
            if (err != null) {
              completer.complete(err);
              return;
            }
            final signedPayjoin = result!.$1;
            await (await blockchain(isTestnet))
                .broadcast(transaction: signedPayjoin);
            print('Broadcasted transaction: $signedPayjoin');
            await _cleanupSession(sessionId);
          } else if (message is Err) {
            print('err: $message');
            await _cleanupSession(sessionId);
          }
        }
      });

      final args = [
        receivePort.sendPort,
        sender.toJson(),
      ];

      await Isolate.spawn(
        _isolateSender,
        args,
      );
      print('spawned isolateSender');

      return completer.future;
    } catch (e) {
      print('err: $e');
      return Err(e.toString());
    }
  }

  Future<void> _cleanupSession(String sessionId) async {
    _activePollers[sessionId]?.kill();
    _activePollers.remove(sessionId);
    _activePorts[sessionId]?.close();
    _activePorts.remove(sessionId);
  }

  Future<bool> checkIsOwned({
    required Uint8List inputScript,
    required bool isTestnet,
    required Wallet wallet,
  }) async {
    final address = await bdk.Address.fromScript(
      script: bdk.ScriptBuf(bytes: inputScript),
      network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
    );
    return await _walletTx.addressExistsInWallet(address.toString(), wallet);
  }

  Future<bool> checkIsReceiverOutput({
    required Uint8List outputScript,
    required bool isTestnet,
    required Wallet wallet,
  }) async {
    final address = await bdk.Address.fromScript(
      script: bdk.ScriptBuf(bytes: Uint8List.fromList(outputScript)),
      network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
    );
    return await _walletTx.addressExistsInWallet(address.toString(), wallet);
  }

  Future<List<bdk.LocalUtxo>> getCandidateInputs({
    required Wallet wallet,
    required bool isTestnet,
  }) async {
    print('get spendable utxos');
    final unspent = await _walletTx.listUnspent(wallet);
    print('unspent: $unspent');
    // final inputs = await Future.wait(
    //   unspent.map((unspent) => inputPairFromUtxo(unspent, isTestnet)),
    // );
    //print('inputs: $inputs');
    return unspent;
  }

  Future<String> processPsbt({
    required String psbt,
    required Wallet wallet,
  }) async {
    print('finalizeProposal psbt $psbt');
    final (signed, err) = await _walletTx.signPsbt(
      psbt: psbt,
      wallet: wallet,
    );
    if (err != null) throw err;
    final signedPsbt = signed!.$2;
    return signedPsbt;
  }
}

Future<String?> pollSender(Sender sender) async {
  print('pollSender');
  final ohttpProxyUrl = await pj_uri.Url.fromStr('https://pj.bobspacebkk.com');
  Request postReq;
  V2PostContext postReqCtx;
  try {
    final result = await sender.extractV2(ohttpProxyUrl: ohttpProxyUrl);
    print('extracted v2');
    postReq = result.$1;
    postReqCtx = result.$2;
  } catch (e) {
    print('failed to extract v2. err: $e');
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
  try {
    print('got post response');
    final getCtx = await postReqCtx.processResponse(
      response: postRes.bodyBytes,
    );
    print('processed post response');
    String? proposalPsbt;
    while (true) {
      print('extracting get request');
      final (getRequest, getReqCtx) = await getCtx.extractReq(
        ohttpRelay: ohttpProxyUrl,
      );
      print('got get request');
      final getRes = await http.post(
        Uri.parse(getRequest.url.asString()),
        headers: {
          'Content-Type': getRequest.contentType,
        },
        body: getRequest.body,
      );
      print('got get response');
      proposalPsbt = await getCtx.processResponse(
        response: getRes.bodyBytes,
        ohttpCtx: getReqCtx,
      );
      print('processed get response');
      break;
    }
    return proposalPsbt;
  } catch (e) {
    print('err: $e');
    throw Exception('Error occurred while polling sender');
  }
}

Future<List<UTXO>> getSpendableUtxosFromBdkWallet(
  bdk.Wallet bdkWallet,
  bdk.Network network,
) async {
  final unspentList = bdkWallet.listUnspent();
  final List<UTXO> list = [];

  for (final unspent in unspentList) {
    final scr = bdk.ScriptBuf(
      bytes: unspent.txout.scriptPubkey.bytes,
    );
    final addresss = await bdk.Address.fromScript(
      script: scr,
      network: network,
    );
    final addressStr = addresss.asString();
    final addressKind = unspent.keychain == bdk.KeychainKind.internalChain
        ? AddressKind.change
        : AddressKind.deposit;

    final utxo = UTXO(
      txid: unspent.outpoint.txid,
      txIndex: unspent.outpoint.vout,
      isSpent: unspent.isSpent,
      value: unspent.txout.value.toInt(),
      spendable: true, // All UTXOs are spendable by default
      address: Address(
        address: addressStr,
        kind: addressKind,
        state: AddressStatus.active,
      ),
      label: '',
    );
    list.add(utxo);
  }

  return list.where((utxo) => utxo.spendable).toList();
}

Future<void> _isolateSender(List<dynamic> args) async {
  await core.init();
  print('_isolateSender');
  final sendPort = args[0] as SendPort;
  final senderJson = args[1] as String;

  final sender = Sender.fromJson(senderJson);
  try {
    final proposalPsbt = await pollSender(sender);
    print('proposalPsbt: $proposalPsbt');
    sendPort.send({
      'type': 'psbt_to_sign',
      'psbt': proposalPsbt,
    });
  } catch (e) {
    sendPort.send(Err(e.toString()));
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
    print('isolateReceivePort message: $message');
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
    print('sendAndWait called with type: $type, data: $data');
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
    print('fallback tx (broadcast this if payjoin fails): $fallbackTx');
    // TODO Handle this. send to the main port on a timer?

    try {
      // Receive Check 1: can broadcast
      print('check1');
      final pj1 = await proposal.assumeInteractiveReceiver();
      print('check2');
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
      print('check3');
      final pj3 = await pj2.checkNoInputsSeenBefore(
        isKnown: (input) {
          // TODO: keep track of seen inputs in hive storage?
          return false;
        },
      );

      // Identify receiver outputs
      print('check4');
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
        unspent.map((utxo) => inputPairFromUtxo(utxo, true)),
      );
      print('selected utxo');
      final selected_utxo = await pj5.tryPreservingPrivacy(
        candidateInputs: candidateInputs,
      );
      print('contribute inputs');
      final pj6 =
          await pj5.contributeInputs(replacementInputs: [selected_utxo]);
      print('commit inputs');
      final pj7 = await pj6.commitInputs();

      // Finalize proposal
      print('finalize proposal');
      final payjoin_proposal = await pj7.finalizeProposal(
        processPsbt: (String psbt) async {
          final result = await sendAndWait(
            'process_psbt',
            {'psbt': psbt},
            sendPort,
          );
          print('process_psbt result: $result');
          return result as String;
        },
        maxFeeRateSatPerVb: BigInt.from(10000),
      );
      return payjoin_proposal;
    } catch (e) {
      print('err: $e');
      throw Exception('Error occurred while finalizing proposal');
    }
  }

  try {
    print('long polling payjoin directory...');
    UncheckedProposal? unchecked_proposal;
    while (unchecked_proposal == null) {
      try {
        final (req, context) = await receiver.extractReq();
        print('making request');
        final ohttpResponse = await http.post(
          Uri.parse(req.url.asString()),
          headers: {
            'Content-Type': req.contentType,
          },
          body: req.body,
        );
        print('got unchecked response');
        unchecked_proposal = await receiver.processRes(
          body: ohttpResponse.bodyBytes,
          ctx: context,
        );
        if (unchecked_proposal != null) {
          break;
        }
      } catch (e) {
        isolateTomainSendPort.send(
          Err(
            e.toString(),
            title: 'Error occurred while processing payjoin',
            solution: 'Please try again.',
          ),
        );
        break;
      }
    }
    final payjoin_proposal = await processPayjoinProposal(
      unchecked_proposal!,
      isolateTomainSendPort,
      isolateReceivePort,
    );
    print('payjoin proposal: $payjoin_proposal');
    try {
      final (postReq, ohttpCtx) = await payjoin_proposal.extractV2Req();
      print('extracted v2 req');
      final postRes = await http.post(
        Uri.parse(postReq.url.asString()),
        headers: {
          'Content-Type': postReq.contentType,
        },
        body: postReq.body,
      );
      print('processed res');
      await payjoin_proposal.processRes(
        res: postRes.bodyBytes,
        ohttpContext: ohttpCtx,
      );
    } catch (e) {
      print('err: $e');
      isolateTomainSendPort.send(
        Err(
          e.toString(),
          title: 'Error occurred while processing payjoin',
          solution: 'Please try again.',
        ),
      );
    }
  } catch (e) {
    isolateTomainSendPort.send(Err(e.toString()));
  }
}

Future<InputPair> inputPairFromUtxo(bdk.LocalUtxo utxo, bool isTestnet) async {
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

Future<(bdk.Wallet?, Err?)> loadPublicBdkWallet(
  bool isTestnet,
  String externalPublicDescriptor,
  String internalPublicDescriptor,
  Directory appDocDir,
  String walletStorageString,
) async {
  try {
    final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;

    final external = await bdk.Descriptor.create(
      descriptor: externalPublicDescriptor,
      network: network,
    );
    final internal = await bdk.Descriptor.create(
      descriptor: internalPublicDescriptor,
      network: network,
    );

    final String dbDir = appDocDir.path + '/$walletStorageString';

    final dbConfig = bdk.DatabaseConfig.sqlite(
      config: bdk.SqliteDbConfiguration(path: dbDir),
    );

    final bdkWallet = await bdk.Wallet.create(
      descriptor: external,
      changeDescriptor: internal,
      network: network,
      databaseConfig: dbConfig,
    );

    return (bdkWallet, null);
  } on Exception catch (e) {
    return (
      null,
      Err(
        e.message,
        title: 'Error occurred while creating wallet',
        solution: 'Please try again.',
      )
    );
  }
}
