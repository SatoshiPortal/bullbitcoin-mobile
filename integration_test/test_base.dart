// import 'dart:async';

// import 'package:boltz/boltz.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:lwk/lwk.dart';
// import 'package:path_provider/path_provider.dart';

// const lNetwork = LiquidNetwork.Testnet;
// const lElectrumUrl = 'blockstream.info:465';

// const swapMnemonic =
//     'bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon';
// const swapIndex = 0;
// const network = Chain.Testnet;
// const electrumUrl = 'electrum.bullbitcoin.com:60002';
// const boltzUrl = 'https://api.testnet.boltz.exchange';
// const testTimeout = Timeout(Duration(minutes: 30));

// const fundingLWalletMnemonic =
//     'fossil install fever ticket wisdom outer broken aspect lucky still flavor dial';

// Future<String> getDbDir() async {
//   try {
//     WidgetsFlutterBinding.ensureInitialized();
//     final directory = await getApplicationDocumentsDirectory();
//     final path = '${directory.path}/lwk-db';
//     return path;
//   } catch (e) {
//     print('Error getting current directory: $e');
//     rethrow;
//   }
// }

// Future<LiquidWallet> setupWallet() async {
//   final dbPath = await getDbDir();
//   final wallet = await LiquidWallet.create(
//     mnemonic: fundingLWalletMnemonic,
//     network: lNetwork,
//     dbPath: dbPath,
//   );
//   await wallet.sync(lElectrumUrl);

//   return wallet;
// }

// Future<LbtcLnSwap> setupLSubmarine(String invoice) async {
//   const amount = 100000;
//   final fees = await AllSwapFees.estimateFee(boltzUrl: boltzUrl, outputAmount: amount);

//   final lbtcLnSubmarineSwap = await LbtcLnSwap.newSubmarine(
//     mnemonic: swapMnemonic,
//     index: swapIndex,
//     invoice: invoice,
//     network: Chain.LiquidTestnet,
//     electrumUrl: electrumUrl,
//     boltzUrl: boltzUrl,
//     pairHash: fees.lbtcPairHash,
//   );

//   return lbtcLnSubmarineSwap;
// }

// Future<LbtcLnSwap> setupLReverseSubmarine(int amount) async {
//   final fees = await AllSwapFees.estimateFee(boltzUrl: boltzUrl, outputAmount: amount);

//   final lbtcLnReverseSwap = await LbtcLnSwap.newReverse(
//     mnemonic: swapMnemonic,
//     index: swapIndex,
//     outAmount: amount,
//     network: Chain.LiquidTestnet,
//     electrumUrl: electrumUrl,
//     boltzUrl: boltzUrl,
//     pairHash: fees.lbtcPairHash,
//   );

//   return lbtcLnReverseSwap;
// }

// Future<String> sendLiquid(LiquidWallet wallet, String address, int amount) async {
//   const absFee = 300.0;
//   final pset = await wallet.build(
//     sats: amount,
//     outAddress: address,
//     absFee: absFee,
//   );
//   // final decodedPset = await wallet.decode(pset: pset);
//   // print('Amount: ${decodedPset.balances.lbtc} , Fee: ${decodedPset.fee}');
//   final signedTxBytes =
//       await wallet.sign(network: lNetwork, pset: pset, mnemonic: fundingLWalletMnemonic);
//   final tx = await wallet.broadcast(
//     electrumUrl: lElectrumUrl,
//     txBytes: signedTxBytes,
//   );
//   // print(tx);
//   await wallet.sync(lElectrumUrl);
//   return tx;
// }

// /// Always pair this with `listenForEventClosure`
// Future<(List<dynamic>, Completer, StreamSubscription)> listenForEventInitiate(
//   String swapId,
//   SwapStatus status,
// ) async {
//   final completer = Completer();
//   final receivedEvents = <dynamic>[];
//   final api = await BoltzApi.newBoltzApi();
//   // ignore: cancel_subscriptions
//   final sub = api.getSwapStatusStream(swapId).listen((event) {
//     receivedEvents.add(event);
//     if (event.status == status) {
//       completer.complete();
//     }
//   });

//   return (receivedEvents, completer, sub);
// }

// Future<void> listenForEventClosure(Completer completer, StreamSubscription sub) async {
//   if (!completer.isCompleted) {
//     await completer.future;
//   }
//   await sub.cancel();
// }
