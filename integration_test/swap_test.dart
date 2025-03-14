@Timeout(Duration(minutes: 30))

import 'dart:async';

import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/_core/domain/services/swap_watcher_service.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/_utils/constants.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/settings/domain/usecases/set_environment_usecase.dart';
import 'package:boltz/boltz.dart' as boltz;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lwk/lwk.dart' as lwk;
import 'package:test/test.dart';

void main() {
  late WalletManagerService walletManagerService;
  late CreateReceiveSwapUseCase receiveSwapUseCase;
  late SwapWatcherService swapWatcherTestnetService;
  late SwapWatcherService swapWatcherMainnetService;
  late SwapRepository swapRepositoryTestnet;
  late SwapRepository swapRepositoryMainnet;
  late Wallet instantWallet;
  late Wallet secureWallet;
  late String receiveLbtcSwapId;
  late String receiveBtcSwapId;
  late int initLiquidBalance;
  late int postReceiveLiquidBalance;
  late int initBitcoinBalance;
  late int postReceiveBitcoinBalance;
  // TODO: Change and move these to github secrets so the testnet coins for our integration
  //  tests are not at risk of being used by others.
  const baseMnemonic =
      'model float claim feature convince exchange truck cream assume fancy swamp offer';

  setUpAll(() async {
    await Future.wait([
      Hive.initFlutter(),
      boltz.LibBoltz.init(),
      lwk.LibLwk.init(),
    ]);
    await AppLocator.setup();
    await locator<SetEnvironmentUseCase>().execute(Environment.mainnet);

    walletManagerService = locator<WalletManagerService>();
    // Use the testnet swap watcher service
    swapWatcherTestnetService = locator<SwapWatcherService>(
      instanceName:
          LocatorInstanceNameConstants.boltzTestnetSwapWatcherInstanceName,
    );
    swapWatcherMainnetService = locator<SwapWatcherService>(
      instanceName: LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
    );
    // Get the testnet swap repository
    swapRepositoryTestnet = locator<SwapRepository>(
      instanceName:
          LocatorInstanceNameConstants.boltzTestnetSwapRepositoryInstanceName,
    );
    swapRepositoryMainnet = locator<SwapRepository>(
      instanceName:
          LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
    );
    receiveSwapUseCase = locator<CreateReceiveSwapUseCase>();

    await locator<CreateDefaultWalletsUseCase>().execute(
      mnemonicWords: baseMnemonic.split(' '),
    );
    final wallets = await walletManagerService.getAllWallets();
    instantWallet = wallets.firstWhere(
      (wallet) => wallet.network == Network.liquidMainnet,
    );
    secureWallet = wallets.firstWhere(
      (wallet) => wallet.network == Network.bitcoinMainnet,
    );
    debugPrint('Wallets created');

    await walletManagerService.syncAll();
    debugPrint('Wallets synced');
  });

  test('Wallets have funds to swap', () async {
    final liquidBalance = await walletManagerService.getBalance(
      walletId: instantWallet.id,
    );
    final bitcoinBalance = await walletManagerService.getBalance(
      walletId: secureWallet.id,
    );
    debugPrint('Liquid balance: $liquidBalance');
    debugPrint('Bitcoin balance: $bitcoinBalance');
    initLiquidBalance = liquidBalance.totalSat.toInt();
    initBitcoinBalance = bitcoinBalance.totalSat.toInt();
  });

  group('Test Reverse Swap For Receive', () {
    group('Bitcoin & Liquid Test', () {
      late StreamSubscription<Swap> swapSubscription;
      late Completer<bool> bitcoinReceiveCompletedEvent;
      late Completer<bool> liquidReceiveCompletedEvent;

      setUpAll(() async {
        bitcoinReceiveCompletedEvent = Completer();
        liquidReceiveCompletedEvent = Completer();
        swapSubscription = swapWatcherMainnetService.swapStream.listen((swap) {
          debugPrint('(Subscriber) Swap Updated.\n${swap.id}:${swap.status}');
          switch (swap.type) {
            case SwapType.lightningToBitcoin:
              if (swap.status == SwapStatus.completed) {
                bitcoinReceiveCompletedEvent.complete(true);
              }
            case SwapType.lightningToLiquid:
              if (swap.status == SwapStatus.completed) {
                liquidReceiveCompletedEvent.complete(true);
              }
            default:
              debugPrint('SOMETHING WENT WRONG');
              debugPrint('Wrong swap type saved');
              return;
          }
        });
      });
      test(
        'Test Storage Persistence',
        () async {
          final ongoingSwaps = await swapRepositoryMainnet.getOngoingSwaps();
          for (final swap in ongoingSwaps) {
            debugPrint('${swap.id}:${swap.status}');
          }
          swapRepositoryMainnet.reinitializeStreamWithSwaps(
            swapIds: ongoingSwaps.map((swap) => swap.id).toList(),
          );
        },
        // skip: 'No swaps started',
      );
      test('Create Liquid Swap. REQUIRED: Pay Invoice', () async {
        final swap = await receiveSwapUseCase.execute(
          walletId: instantWallet.id,
          type: SwapType.lightningToLiquid,
          amountSat: 1001,
        );
        debugPrint('Fees:\n');
        debugPrint('Boltz Fee: ${swap.boltzFee}\n');
        debugPrint('Lockup Fee: ${swap.lockupFee}\n');
        debugPrint('Claim Fee: ${swap.claimFee}\n');
        expect(swap, isNotNull);
        receiveLbtcSwapId = swap.id;
        expect(swap.status, SwapStatus.pending);
        debugPrint("Pay invoice:\n");
        debugPrint(swap.invoice);
        debugPrint("SwapID: ${swap.id}");
        debugPrint('\n\n\n');
      });
      test(
        'Create Bitcoin Swap. REQUIRED: Pay Invoice',
        () async {
          final swap = await receiveSwapUseCase.execute(
            walletId: secureWallet.id,
            type: SwapType.lightningToBitcoin,
            amountSat: 25001,
          );
          expect(swap, isNotNull);
          receiveBtcSwapId = swap.id;
          expect(swap.status, SwapStatus.pending);
          debugPrint("Pay invoice:\n");
          debugPrint(swap.invoice);
          debugPrint("SwapID: ${swap.id}");
          debugPrint('\n\n\n');
        },
        skip: 'Bitcoin swap takes very long to complete',
      );
      test('Wait for Liquid Swap to Complete', () async {
        final isComplete = await liquidReceiveCompletedEvent.future;
        expect(
          isComplete,
          isTrue,
          reason: 'Liquid receive swap did not complete',
        );
      });
      test('Check Liquid Balance After Swap', () async {
        debugPrint(
            'Waiting 60 seconds for transaction to confirm to check balances');
        await Future.delayed(const Duration(seconds: 60));
        await walletManagerService.sync(walletId: instantWallet.id);
        final liquidBalance = await walletManagerService.getBalance(
          walletId: instantWallet.id,
        );
        final receiveSwap = await swapRepositoryMainnet.getSwap(
          swapId: receiveLbtcSwapId,
        ) as LnReceiveSwap;
        final totalSwapFees = receiveSwap.boltzFee! +
            receiveSwap.claimFee! +
            receiveSwap.lockupFee!;
        debugPrint('Total Swap Fees: $totalSwapFees');
        final decodedInvoice = await swapRepositoryMainnet.decodeInvoice(
          invoice: receiveSwap.invoice,
        );
        final receivableAmount = decodedInvoice.sats - totalSwapFees;
        debugPrint('Receivable Amount: $receivableAmount');
        final expectedLiquidBalanceAfterSwap =
            initLiquidBalance + receivableAmount;
        debugPrint('Expected Balance: $expectedLiquidBalanceAfterSwap');
        debugPrint(
            'Liquid Balance (totalSat): ${liquidBalance.totalSat.toInt()}');
        expect(
          expectedLiquidBalanceAfterSwap,
          liquidBalance.totalSat.toInt(),
          reason: 'Liquid balance should increment by (invoice amount - fees)',
        );
      });
      test(
        'Wait for Bitcoin Swap to Complete',
        () async {
          final isComplete = await bitcoinReceiveCompletedEvent.future;
          expect(
            isComplete,
            isTrue,
            reason: 'Liquid receive swap did not complete',
          );
        },
        skip: 'Bitcoin swap takes very long to complete',
      );

      tearDownAll(() {
        swapSubscription.cancel();
      });
    });
  });
}
