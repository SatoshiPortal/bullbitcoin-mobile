// import 'dart:async';

// import 'package:boltz_dart/boltz_dart.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:lwk_dart/lwk_dart.dart';

// import 'lwk_test.data.dart';
// import 'test_base.dart';

// late LiquidWallet wallet;

// const testTimeout = Timeout(Duration(minutes: 30));

// void main() {
//   setUpAll(() async {
//     wallet = await setupWallet();
//   });

//   group('General', () {
//     test('getBalance', () async {
//       final Balance b = await wallet.balance();
//       print(b.lbtc);
//     });

//     test('sendAmount', () async {
//       try {
//         final String txid = await sendLiquid(
//           wallet,
//           baconWalletAddress,
//           3000,
//         );
//         print(txid);
//       } catch (e) {
//         print(e);
//       }
//     });
//   });
//   group('LBTC-LN Submarince', () {
//     test('Neg: Minimum limit (1k sats)', () async {
//       // An invoice with <1k sats
//       await expectLater(
//         () async => await setupLSubmarine(invoice600),
//         throwsA(
//           predicate((e) {
//             return e is BoltzError &&
//                 e.kind == 'BoltzApi' &&
//                 e.message == '{"error":"$invoice600Amount is less than minimal of 1000"}';
//           }),
//         ),
//       );
//     });

//     test('Neg: Maximum limit (25m sats)', () async {
//       // An invoice with >25m sats
//       await expectLater(
//         () async => await setupLSubmarine(invoice26m),
//         throwsA(
//           predicate((e) {
//             return e is BoltzError &&
//                 e.kind == 'BoltzApi' &&
//                 e.message == '{"error":"$invoice26mAmount is exceeds maximal of 25000000"}';
//           }),
//         ),
//       );
//     });

//     test('Neg: Used Invoice', () async {
//       await expectLater(
//         () async => await setupLSubmarine(usedInvoice),
//         throwsA(
//           predicate((e) {
//             return e is BoltzError &&
//                 e.kind == 'BoltzApi' &&
//                 e.message == '{"error":"a swap with this invoice exists already"}';
//           }),
//         ),
//       );
//     });

//     test('Neg: Expired invoice', () async {
//       await expectLater(
//         () async => await setupLSubmarine(expiredInvoice),
//         throwsA(
//           predicate((e) {
//             return e is BoltzError &&
//                 e.kind == 'BoltzApi' &&
//                 e.message == '{"error":"the provided invoice expired already"}';
//           }),
//         ),
//       );
//     });

//     test('Neg: Invalid invoice', () async {
//       await expectLater(
//         () async => await setupLSubmarine(invalidInvoice),
//         throwsA(
//           predicate((e) {
//             print(e);
//             return e is BoltzError &&
//                 e.kind == 'BoltzApi' &&
//                 e.message == '{"error":"No separator character for lntbinvalidinvoice"}';
//           }),
//         ),
//       );
//     });

//     test(
//       'Neg: Send less on-chain sats',
//       () async {
//         final LbtcLnSwap lbtcLnSubmarine = await setupLSubmarine(workingFreshInvoice1);

//         const expectedSecretKey =
//             '9b496356fbb59d95656acc879a5d7a9169eb3d77e5b7c511aeb827925e5b49e9';

//         final swap = lbtcLnSubmarine.lbtcLnSwap;
//         print('SWAP CREATED SUCCESSFULLY: ${swap.id}');

//         final (receivedEvents, completer, sub) =
//             await listenForEventInitiate(swap.id, SwapStatus.txnLockupFailed);

//         final paymentDetails = await lbtcLnSubmarine.paymentDetails();
//         expect(swap.keys.secretKey, expectedSecretKey);
//         final outAddress = paymentDetails.split(':')[0];
//         final outAmount = int.parse(paymentDetails.split(':')[1]);
//         print('Expected: $outAmount. But sending only 1000 to: $outAddress');
//         final txid = await sendLiquid(wallet, outAddress, 1000);
//         print('TXID: $txid');

//         await listenForEventClosure(completer, sub);

//         expect(receivedEvents[0].status, equals(SwapStatus.invoiceSet));
//         expect(receivedEvents[1].status, equals(SwapStatus.txnLockupFailed));

//         // TODO: Getting refund
//       },
//       skip: true,
//       timeout: testTimeout,
//     );

//     test(
//       'Neg: LN Invoice expires',
//       () async {
//         final LbtcLnSwap lbtcLnSubmarine = await setupLSubmarine(invoiceWith2minExpiry);

//         const expectedSecretKey =
//             '9b496356fbb59d95656acc879a5d7a9169eb3d77e5b7c511aeb827925e5b49e9';

//         final swap = lbtcLnSubmarine.lbtcLnSwap;
//         print('SWAP CREATED SUCCESSFULLY: ${swap.id}');

//         final (receivedEvents, completer, sub) =
//             await listenForEventInitiate(swap.id, SwapStatus.invoiceFailedToPay);

//         final paymentDetails = await lbtcLnSubmarine.paymentDetails();
//         expect(swap.keys.secretKey, expectedSecretKey);
//         final outAddress = paymentDetails.split(':')[0];
//         final outAmount = int.parse(paymentDetails.split(':')[1]);
//         print('Sending expected amount $outAmount to $outAddress, after Invoice expires (2m)');
//         await Future.delayed(const Duration(seconds: 120));
//         final txid = await sendLiquid(wallet, outAddress, outAmount);
//         print('TXID: $txid');

//         await listenForEventClosure(completer, sub);

//         expect(receivedEvents[0].status, equals(SwapStatus.invoiceSet));
//         expect(receivedEvents[1].status, equals(SwapStatus.txnMempool));
//         expect(receivedEvents[2].status, equals(SwapStatus.invoicePending));
//         expect(receivedEvents[3].status, equals(SwapStatus.invoiceFailedToPay));

//         // TODO: Getting refund
//       },
//       skip: true,
//       timeout: testTimeout,
//     );

//     test(
//       'Positive',
//       () async {
//         final LbtcLnSwap lbtcLnSubmarine = await setupLSubmarine(workingFreshInvoice2);

//         const expectedSecretKey =
//             '9b496356fbb59d95656acc879a5d7a9169eb3d77e5b7c511aeb827925e5b49e9';

//         final swap = lbtcLnSubmarine.lbtcLnSwap;
//         print('SWAP CREATED SUCCESSFULLY: ${swap.id}');

//         final (receivedEvents, completer, sub) =
//             await listenForEventInitiate(swap.id, SwapStatus.txnClaimed);

//         final paymentDetails = await lbtcLnSubmarine.paymentDetails();
//         expect(swap.keys.secretKey, expectedSecretKey);
//         final outAddress = paymentDetails.split(':')[0];
//         final outAmount = int.parse(paymentDetails.split(':')[1]);
//         print('Sending expected amount $outAmount to $outAddress');
//         final txid = await sendLiquid(wallet, outAddress, outAmount);
//         print('TXID: $txid');

//         await listenForEventClosure(completer, sub);

//         expect(receivedEvents[0].status, equals(SwapStatus.invoiceSet));
//         expect(receivedEvents[1].status, equals(SwapStatus.txnMempool));
//         expect(receivedEvents[2].status, equals(SwapStatus.invoicePending));
//         expect(receivedEvents[3].status, equals(SwapStatus.invoicePaid));
//         expect(receivedEvents[4].status, equals(SwapStatus.txnClaimed));
//       },
//       skip: true,
//       timeout: testTimeout,
//     );
//   });
//   group('LN-LBTC Reverse Submarine', () {
//     test(
//       'Positive',
//       () async {
//         const int lbtcLnReverseSwapAmount = 2000;
//         const String lBtcReceiveAddress = fundingWalletAddress;
//         final LbtcLnSwap lbtcLnSubmarine = await setupLReverseSubmarine(lbtcLnReverseSwapAmount);

//         const expectedSecretKey =
//             'a0a62dd7225288f41a741c293a3220035b4c71686dc34c01ec84cbe6ab11b4e1';

//         final swap = lbtcLnSubmarine.lbtcLnSwap;
//         print('SWAP CREATED SUCCESSFULLY: ${swap.id}');
//         expect(swap.keys.secretKey, expectedSecretKey);

//         print('Pay this invoice: ${swap.invoice}');

//         final completer = Completer();
//         final receivedEvents = <dynamic>[];
//         final api = await BoltzApi.newBoltzApi();
//         final sub = api.getSwapStatusStream(swap.id).listen((event) async {
//           receivedEvents.add(event);
//           if (event.status == SwapStatus.txnMempool) {
//             await Future.delayed(const Duration(seconds: 20));

//             final fees = await AllSwapFees.estimateFee(
//               boltzUrl: boltzUrl,
//               outputAmount: lbtcLnReverseSwapAmount,
//             );
//             final claimFeesEstimate = fees.lbtcReverse.claimFeesEstimate;

//             final String txnId = await lbtcLnSubmarine.claim(
//               outAddress: lBtcReceiveAddress,
//               absFee: claimFeesEstimate,
//             );
//             print(txnId);
//           }
//           if (event.status == SwapStatus.invoiceSettled) {
//             completer.complete();
//           }
//         });
//         await completer.future;

//         await sub.cancel();

//         print(receivedEvents);
//         // expect(receivedEvents[0].status, equals(SwapStatus.invoiceSet));
//         // expect(receivedEvents[0].status, equals(SwapStatus.swapCreated));
//         // expect(receivedEvents[1].status, equals(SwapStatus.txnMempool));
//         // expect(receivedEvents[2].status, equals(SwapStatus.invoiceSettled));
//       },
//       skip: true,
//       timeout: testTimeout,
//     );
//   });
// }
