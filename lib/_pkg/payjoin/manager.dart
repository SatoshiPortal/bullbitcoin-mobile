import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:payjoin_flutter/bitcoin_ffi.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/receive.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:payjoin_flutter/src/generated/frb_generated.dart';
import 'package:payjoin_flutter/uri.dart' as pj_uri;

class PayjoinManager {
  PayjoinManager(this._networkCubit);
  final NetworkCubit _networkCubit;

  Isolate? _receiverIsolate;
  ReceivePort? _receiverPort;

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
      _receiverPort = ReceivePort();
      final network = _networkCubit.state.getNetwork();
      final dbDir = (await getApplicationDocumentsDirectory()).path +
          '/${wallet.getWalletStorageString()}';
      final args = [
        _receiverPort!.sendPort,
        receiver.toJson(),
        isTestnet,
        wallet.externalPublicDescriptor,
        wallet.internalPublicDescriptor,
        dbDir,
        network?.stopGap,
        network?.timeout,
        network?.retry,
        if (isTestnet) network?.testnet else network?.mainnet,
        network?.validateDomain,
      ];
      _receiverIsolate = await Isolate.spawn(
        _isolateReceiver,
        args,
      );

      _receiverPort!.listen((message) {
        if (message is Err) {
          completer.complete(message);
        }
      });

      return completer.future;
    } catch (e) {
      print('err: $e');
      return Err(
        e.toString(),
        title: 'Error occurred while syncing Payjoins',
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
      final dbDir = (await getApplicationDocumentsDirectory()).path +
          '/${wallet.getWalletStorageString()}';

      final network = _networkCubit.state.getNetwork();

      final args = [
        receivePort.sendPort,
        sender.toJson(),
        isTestnet,
        wallet.externalPublicDescriptor,
        wallet.internalPublicDescriptor,
        dbDir,
        network?.stopGap,
        network?.timeout,
        network?.retry,
        if (isTestnet) network?.testnet else network?.mainnet,
        network?.validateDomain,
      ];

      await Isolate.spawn(
        _isolateSender,
        args,
      );
      print('spawned isolateSender');

      receivePort.listen((message) {
        if (message is Err) {
          completer.complete(message);
        } else {
          completer.complete(null);
        }
      });

      return completer.future;
    } catch (e) {
      print('err: $e');
      return Err(e.toString());
    }
  }

  void cancelSync() {
    _receiverIsolate?.kill(priority: Isolate.immediate);
    _receiverPort?.close();
  }
}

Future<String?> pollSender(Sender sender) async {
  print('pollSender');
  final ohttpProxyUrl = await pj_uri.Url.fromStr('https://ohttp.achow101.com');
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

Future<bool> addressExistsInWallet(String address, bdk.Wallet bdkWallet) async {
  // Get the full address book
  final addresses = await getAddressBookFromBdkWallet(bdkWallet);

  // Check if the address exists in the list
  return addresses.any((addr) => addr.address == address);
}

Future<List<Address>> getAddressBookFromBdkWallet(bdk.Wallet bdkWallet) async {
  final List<Address> addresses = [];

  // Get last unused address to know how many addresses to check
  final addressLastUnused = bdkWallet.getAddress(
    addressIndex: const bdk.AddressIndex.lastUnused(),
  );

  // Iterate through all addresses up to last unused
  for (var i = 0; i <= addressLastUnused.index; i++) {
    final address = bdkWallet.getAddress(
      addressIndex: bdk.AddressIndex.peek(index: i),
    );
    final addressStr = address.address.asString();

    addresses.add(
      Address(
        address: addressStr,
        index: address.index,
        kind: AddressKind.deposit,
        state: AddressStatus.unused,
      ),
    );
  }

  // Sort addresses by index descending
  addresses.sort((a, b) {
    final int indexA = a.index ?? 0;
    final int indexB = b.index ?? 0;
    return indexB.compareTo(indexA);
  });

  return addresses;
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
  final isTestnet = args[2] as bool;
  final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;
  final externalPublicDescriptor = args[3] as String;
  final internalPublicDescriptor = args[4] as String;
  final external = await bdk.Descriptor.create(
    descriptor: externalPublicDescriptor,
    network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
  );
  final internal = await bdk.Descriptor.create(
    descriptor: internalPublicDescriptor,
    network: network,
  );
  final dbDir = args[5] as String;

  final stopGap = args[6] as int;
  final timeout = args[7] as int;
  final retry = args[8] as int;
  final url = args[9] as String;
  final validateDomain = args[10] as bool;

  try {
    final sender = Sender.fromJson(senderJson);
    final wallet = await bdk.Wallet.create(
      descriptor: external,
      changeDescriptor: internal,
      network: network,
      databaseConfig: bdk.DatabaseConfig.sqlite(
        config: bdk.SqliteDbConfiguration(path: dbDir),
      ),
    );
    final blockchain = await bdk.Blockchain.create(
      config: bdk.BlockchainConfig.electrum(
        config: bdk.ElectrumConfig(
          url: url,
          retry: retry,
          timeout: timeout,
          stopGap: BigInt.from(stopGap),
          validateDomain: validateDomain,
        ),
      ),
    );
    final proposal = await pollSender(sender);

    // SIGN AND BROADCAST ---------------------------
    try {
      print('signing');
      final psbtStruct =
          await bdk.PartiallySignedTransaction.fromString(proposal!);
      await wallet.sign(
        psbt: psbtStruct,
        signOptions: const bdk.SignOptions(
          trustWitnessUtxo: true,
          allowAllSighashes: false,
          removePartialSigs: true,
          tryFinalize: true,
          signWithTapInternalKey: false,
          allowGrinding: true,
        ),
      );
      print('signed');
      final finalizedTx = psbtStruct.extractTx();
      final signedPsbt = psbtStruct.toString();

      //Broadcast the transaction
      print('broadcasting');
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
  } catch (e) {
    sendPort.send(Err(e.toString()));
  }
}

void _isolateReceiver(List<dynamic> args) async {
  await core.init();
  final sendPort = args[0] as SendPort;
  final receiver = Receiver.fromJson(args[1] as String);
  final isTestnet = args[2] as bool;
  final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;
  final externalPublicDescriptor = args[3] as String;
  final internalPublicDescriptor = args[4] as String;
  final external = await bdk.Descriptor.create(
    descriptor: externalPublicDescriptor,
    network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
  );
  final internal = await bdk.Descriptor.create(
    descriptor: internalPublicDescriptor,
    network: network,
  );
  final dbDir = args[5] as String;

  final stopGap = args[6] as int;
  final timeout = args[7] as int;
  final retry = args[8] as int;
  final url = args[9] as String;
  final validateDomain = args[10] as bool;

  try {
    final wallet = await bdk.Wallet.create(
      descriptor: external,
      changeDescriptor: internal,
      network: network,
      databaseConfig: bdk.DatabaseConfig.sqlite(
        config: bdk.SqliteDbConfiguration(path: dbDir),
      ),
    );
    final blockchain = await bdk.Blockchain.create(
      config: bdk.BlockchainConfig.electrum(
        config: bdk.ElectrumConfig(
          url: url,
          retry: retry,
          timeout: timeout,
          stopGap: BigInt.from(stopGap),
          validateDomain: validateDomain,
        ),
      ),
    );
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
        sendPort.send(
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
      isTestnet,
      wallet,
      blockchain,
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
      sendPort.send(
        Err(
          e.toString(),
          title: 'Error occurred while processing payjoin',
          solution: 'Please try again.',
        ),
      );
    }
  } catch (e) {
    sendPort.send(Err(e.toString()));
  }
}

Future<PayjoinProposal> processPayjoinProposal(
  UncheckedProposal proposal,
  bool isTestnet,
  bdk.Wallet wallet,
  bdk.Blockchain blockchain,
) async {
  final fallbackTx = await proposal.extractTxToScheduleBroadcast();
  print('fallback tx (broadcast this if payjoin fails): $fallbackTx');

  try {
    // Receive Check 1: can broadcast
    print('check1');
    final pj1 = await proposal.assumeInteractiveReceiver();
    print('check2');
    // Receive Check 2: original PSBT has no receiver-owned inputs
    final pj2 = await pj1.checkInputsNotOwned(
      isOwned: (inputScript) async {
        final address = await bdk.Address.fromScript(
          script: bdk.ScriptBuf(bytes: inputScript),
          network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
        );
        return await addressExistsInWallet(address.toString(), wallet);
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
        final address = await bdk.Address.fromScript(
          script: bdk.ScriptBuf(bytes: outputScript),
          network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
        );
        return await addressExistsInWallet(address.toString(), wallet);
      },
    );
    final pj5 = await pj4.commitOutputs();

    // Contribute receiver inputs
    print('get spendable utxos');
    final unspent = wallet.listUnspent();
    final inputs = await Future.wait(
      unspent.map((unspent) => inputPairFromUtxo(unspent, isTestnet)),
    );
    print('selected utxo');
    final selected_utxo = await pj5.tryPreservingPrivacy(
      candidateInputs: inputs,
    );
    print('contribute inputs');
    final pj6 = await pj5.contributeInputs(replacementInputs: [selected_utxo]);
    print('commit inputs');
    final pj7 = await pj6.commitInputs();

    // Finalize proposal
    print('finalize proposal');
    final payjoin_proposal = await pj7.finalizeProposal(
      processPsbt: (String psbt) async {
        print('finalizeProposal psbt $psbt');
        // TODO: sign PSBT
        final psbtStruct =
            await bdk.PartiallySignedTransaction.fromString(psbt);
        print('unsigned psbtStruct $psbtStruct');
        final signed = await wallet.sign(
          psbt: psbtStruct,
          signOptions: const bdk.SignOptions(
            trustWitnessUtxo: false,
            allowAllSighashes: false,
            removePartialSigs: true,
            tryFinalize: true,
            signWithTapInternalKey: true,
            allowGrinding: true,
          ),
        );
        print('signed $signed');
        final signedPsbt = psbtStruct.toString();
        print('signedPsbt $signedPsbt');
        return signedPsbt;
      },
      maxFeeRateSatPerVb: BigInt.from(10000),
    );
    return payjoin_proposal;
  } catch (e) {
    print('err: $e');
    throw Exception('Error occurred while finalizing proposal');
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
