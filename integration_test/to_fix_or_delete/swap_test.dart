// import 'dart:async';

// import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
// import 'package:bb_mobile/core/swaps/data/services/swap_watcher.dart';
// import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
// import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
// import 'package:bb_mobile/core/swaps/domain/services/swap_watcher_service.dart';
// import 'package:bb_mobile/core/utils/constants.dart';
// import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
// import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
// import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
// import 'package:bb_mobile/features/receive/domain/usecases/create_receive_swap_use_case.dart';
// import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
// import 'package:bb_mobile/locator.dart';
// import 'package:boltz/boltz.dart' as boltz;
// import 'package:flutter/material.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:lwk/lwk.dart' as lwk;
// import 'package:test/test.dart';

// void main() {
//   late WalletRepository walletRepository;
//   late CreateReceiveSwapUsecase receiveSwapUsecase;
//   // late SwapWatcherService swapWatcherTestnetService;
//   late SwapWatcherService swapWatcherMainnetService;
//   // late SwapRepository swapRepositoryTestnet;
//   late SwapRepository swapRepositoryMainnet;
//   late Wallet instantWallet;
//   late Wallet secureWallet;
//   late String receiveLbtcSwapId;
//   late String receiveBtcSwapId;
//   late int initLiquidBalance;
//   // late int postReceiveLiquidBalance;
//   // late int initBitcoinBalance;
//   // late int postReceiveBitcoinBalance;
//   // TODO: Change and move these to github secrets so the testnet coins for our integration
//   //  tests are not at risk of being used by others.
//   const baseMnemonic =
//       'model float claim feature convince exchange truck cream assume fancy swamp offer';

//   /*
//    * 
//    * 
//    * INVOICES MUST BE UPDATED FOR EVERY TEST OF SUBMARINE SEND SWAPS
//    * 
//    * 
//    */
//   // const liquidSendInvoice = '';
//   // const bitcoinSendInvoice = '';

//   setUpAll(() async {
//     await Future.wait([
//       dotenv.load(isOptional: true),
//       boltz.LibBoltz.init(),
//       lwk.LibLwk.init(),
//       AppLocator.setup(),
//     ]);
//     await locator<SetEnvironmentUsecase>().execute(Environment.mainnet);

//     // await locator<SqliteDatabase>().seedTables();

//     walletRepository = locator<WalletRepository>();
//     // Use the testnet swap watcher service
//     // swapWatcherTestnetService = locator<SwapWatcherService>(
//     //   instanceName:
//     //       LocatorInstanceNameConstants.boltzTestnetSwapWatcherInstanceName,
//     // );
//     swapWatcherMainnetService = locator<SwapWatcherService>(
//       instanceName: LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
//     );
//     // Get the testnet swap repository
//     // swapRepositoryTestnet = locator<SwapRepository>(
//     //   instanceName:
//     //       LocatorInstanceNameConstants.boltzTestnetSwapRepositoryInstanceName,
//     // );
//     swapRepositoryMainnet = locator<SwapRepository>(
//       instanceName:
//           LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
//     );
//     receiveSwapUsecase = locator<CreateReceiveSwapUsecase>();

//     await locator<CreateDefaultWalletsUsecase>().execute(
//       mnemonicWords: baseMnemonic.split(' '),
//     );
//     final wallets = await walletRepository.getWallets();
//     instantWallet = wallets.firstWhere(
//       (wallet) => wallet.network == Network.liquidMainnet,
//     );
//     secureWallet = wallets.firstWhere(
//       (wallet) => wallet.network == Network.bitcoinMainnet,
//     );
//     debugPrint('Wallets created');

//     await walletRepository.getWallets(sync: true);
//     debugPrint('Wallets synced');
//   });

//   test('Wallets have funds to swap', () {
//     final liquidBalance = instantWallet.balanceSat;
//     final bitcoinBalance = secureWallet.balanceSat;
//     debugPrint('Liquid balance: $liquidBalance');
//     debugPrint('Bitcoin balance: $bitcoinBalance');
//     initLiquidBalance = liquidBalance.toInt();
//     // initBitcoinBalance = bitcoinBalance.totalSat.toInt();
//   });

//   group('Test All Swaps', () {
//     late StreamSubscription<Swap> swapSubscription;
//     late Completer<bool> bitcoinReceiveCompletedEvent;
//     late Completer<bool> liquidReceiveCompletedEvent;
//     late Completer<bool> bitcoinSendCompletedEvent;
//     late Completer<bool> liquidSendCompletedEvent;

//     setUpAll(() {
//       bitcoinReceiveCompletedEvent = Completer();
//       liquidReceiveCompletedEvent = Completer();
//       bitcoinSendCompletedEvent = Completer();
//       liquidSendCompletedEvent = Completer();
//       swapSubscription = swapWatcherMainnetService.swapStream.listen((swap) {
//         debugPrint(
//           '(Subscriber) Swap Updated.\n${swap.id}:${swap.status}:${swap.type}',
//         );
//         switch (swap.type) {
//           case SwapType.lightningToBitcoin:
//             if (swap.status == SwapStatus.completed) {
//               bitcoinReceiveCompletedEvent.complete(true);
//             }
//           case SwapType.lightningToLiquid:
//             if (swap.status == SwapStatus.completed) {
//               liquidReceiveCompletedEvent.complete(true);
//             }
//           case SwapType.liquidToLightning:
//             if (swap.status == SwapStatus.completed) {
//               liquidSendCompletedEvent.complete(true);
//             }
//           case SwapType.bitcoinToLightning:
//             if (swap.status == SwapStatus.completed) {
//               bitcoinSendCompletedEvent.complete(true);
//             }
//           case SwapType.liquidToBitcoin:
//           case SwapType.bitcoinToLiquid:
//             return;
//         }
//       });
//     });

//     test('Create Liquid Receive Swap. REQUIRED: Pay Invoice', () async {
//       final swap = await receiveSwapUsecase.execute(
//         walletId: instantWallet.id,
//         type: SwapType.lightningToLiquid,
//         amountSat: 1001,
//       );
//       debugPrint('Fees:\n');
//       debugPrint('Boltz Fee: ${swap.fees?.boltzFee!}\n');
//       debugPrint('Lockup Fee: ${swap.fees?.lockupFee}\n');
//       debugPrint('Claim Fee: ${swap.fees?.claimFee}\n');
//       expect(swap, isNotNull);
//       receiveLbtcSwapId = swap.id;
//       expect(swap.status, SwapStatus.pending);
//       debugPrint("Pay invoice:\n");
//       debugPrint(swap.invoice);
//       debugPrint("SwapID: ${swap.id}");
//       debugPrint('\n\n\n');
//     });
//     test(
//       'Create Bitcoin Receive Swap. REQUIRED: Pay Invoice',
//       () async {
//         final swap = await receiveSwapUsecase.execute(
//           walletId: secureWallet.id,
//           type: SwapType.lightningToBitcoin,
//           amountSat: 25001,
//         );
//         expect(swap, isNotNull);
//         receiveBtcSwapId = swap.id;
//         expect(swap.status, SwapStatus.pending);
//         debugPrint("Pay invoice:\n");
//         debugPrint(swap.invoice);
//         debugPrint("SwapID: ${swap.id}");
//         debugPrint('\n\n\n');
//       },
//       skip: 'Bitcoin swap takes very long to complete',
//     );
//     test('Wait for Liquid Receive Swap to Complete', () async {
//       final isComplete = await liquidReceiveCompletedEvent.future;
//       expect(isComplete, isTrue, reason: 'Liquid receive swap completed');
//     });
//     test('Check Liquid Receive Swap Status', () async {
//       final receiveSwap =
//           await swapRepositoryMainnet.getSwap(swapId: receiveLbtcSwapId)
//               as LnReceiveSwap;
//       expect(
//         receiveSwap.status,
//         SwapStatus.completed,
//         reason: 'Swap should be completed',
//       );
//       expect(
//         receiveSwap.receiveTxid != null,
//         true,
//         reason: 'Swap should have a receive txid',
//       );
//       expect(
//         receiveSwap.receiveAddress != null,
//         true,
//         reason: 'Swap should have a receive address',
//       );
//     });
//     // TODO: Instead of checking balance; check transactions, match by txid and check transaction amount
//     test('Check Liquid Balance After Receive Swap', () async {
//       debugPrint(
//         'Waiting 60 seconds for transaction to confirm to check balances',
//       );
//       await Future.delayed(const Duration(seconds: 60));
//       final wallet = await walletRepository.getWallet(
//         instantWallet.id,
//         sync: true,
//       );
//       if (wallet == null) throw 'Instant wallet not found';
//       instantWallet = wallet;

//       final liquidBalance = instantWallet.balanceSat;
//       final receiveSwap =
//           await swapRepositoryMainnet.getSwap(swapId: receiveLbtcSwapId)
//               as LnReceiveSwap;

//       final decodedInvoice = await swapRepositoryMainnet.decodeInvoice(
//         invoice: receiveSwap.invoice,
//       );
//       final totalSwapFees =
//           receiveSwap.fees?.totalFees(decodedInvoice.sats) ?? 0;
//       debugPrint('Total Swap Fees: $totalSwapFees');
//       final receivableAmount = decodedInvoice.sats - totalSwapFees;
//       debugPrint('Receivable Amount: $receivableAmount');
//       final expectedLiquidBalanceAfterSwap =
//           initLiquidBalance + receivableAmount;
//       debugPrint('Expected Balance: $expectedLiquidBalanceAfterSwap');
//       debugPrint('Liquid Balance (totalSat): ${liquidBalance.toInt()}');
//       expect(
//         expectedLiquidBalanceAfterSwap,
//         liquidBalance.toInt(),
//         reason: 'Liquid balance should increment by (invoice amount - fees)',
//       );
//     });
//     test(
//       'Wait for Bitcoin Receive Swap to Complete',
//       () async {
//         final isComplete = await bitcoinReceiveCompletedEvent.future;
//         expect(
//           isComplete,
//           isTrue,
//           reason: 'Liquid receive swap did not complete',
//         );
//       },
//       skip: 'Bitcoin swap takes very long to complete',
//     );

//     test('Check Bitcoin Receive Swap Status', () async {
//       final receiveSwap =
//           await swapRepositoryMainnet.getSwap(swapId: receiveBtcSwapId)
//               as LnReceiveSwap;
//       expect(
//         receiveSwap.status,
//         SwapStatus.completed,
//         reason: 'Swap should be completed',
//       );
//       expect(
//         receiveSwap.receiveTxid != null,
//         true,
//         reason: 'Swap should have a receive txid',
//       );
//       expect(
//         receiveSwap.receiveAddress != null,
//         true,
//         reason: 'Swap should have a receive address',
//       );
//     });

//     tearDownAll(() {
//       swapSubscription.cancel();
//     });
//   }, timeout: const Timeout(Duration(minutes: 30)));
// }
