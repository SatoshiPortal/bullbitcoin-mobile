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
  late SwapWatcherService swapWatcherService;
  late SwapRepository swapRepositoryTestnet;
  late Wallet instantWallet;
  late Wallet secureWallet;

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
    await locator<SetEnvironmentUseCase>().execute(Environment.testnet);

    walletManagerService = locator<WalletManagerService>();
    // Use the testnet swap watcher service
    swapWatcherService = locator<SwapWatcherService>(
      instanceName:
          LocatorInstanceNameConstants.boltzTestnetSwapWatcherInstanceName,
    );
    // Get the testnet swap repository
    swapRepositoryTestnet = locator<SwapRepository>(
      instanceName:
          LocatorInstanceNameConstants.boltzTestnetSwapRepositoryInstanceName,
    );

    receiveSwapUseCase = locator<CreateReceiveSwapUseCase>();

    // receiverWallet = await locator<RecoverWalletUseCase>().execute(
    //   mnemonicWords: receiverMnemonic.split(' '),
    //   scriptType: ScriptType.bip84,
    // );
    // senderWallet = await locator<RecoverWalletUseCase>().execute(
    //   mnemonicWords: senderMnemonic.split(' '),
    //   scriptType: ScriptType.bip84,
    // );
    await locator<CreateDefaultWalletsUseCase>().execute(
      mnemonicWords: baseMnemonic.split(' '),
    );
    final wallets = await walletManagerService.getAllWallets();
    instantWallet = wallets.firstWhere(
      (wallet) => wallet.network == Network.liquidTestnet,
    );
    secureWallet = wallets.firstWhere(
      (wallet) => wallet.network == Network.bitcoinTestnet,
    );
    debugPrint('Wallets created');
  });

  setUp(() async {
    // Sync the wallets before every other test
    await walletManagerService.syncAll();
    debugPrint('Wallets synced');
  });

  test('Test Boltz Api', () async {
    // Get swap limits for Lightning to Bitcoin
    final btcLimits = await swapRepositoryTestnet.getSwapLimits(
      type: SwapType.lightningToBitcoin,
    );

    debugPrint('Lightning to Bitcoin min: ${btcLimits.min} sats');
    debugPrint('Lightning to Bitcoin max: ${btcLimits.max} sats');

    expect(btcLimits.min, greaterThan(0));
    expect(btcLimits.max, greaterThan(btcLimits.min));

    // Get swap limits for Lightning to Liquid
    final liquidLimits = await swapRepositoryTestnet.getSwapLimits(
      type: SwapType.lightningToLiquid,
    );

    debugPrint('Lightning to Liquid min: ${liquidLimits.min} sats');
    debugPrint('Lightning to Liquid max: ${liquidLimits.max} sats');

    expect(liquidLimits.min, greaterThan(0));
    expect(liquidLimits.max, greaterThan(liquidLimits.min));
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
  });

  group('Test Reverse Swap For Receive', () {
    group('Bitcoin & Liquid Test', () {
      late StreamSubscription<Swap> _swapSubscription;
      late Completer<bool> bitcoinReceiveCompletedEvent;
      late Completer<bool> liquidReceiveCompletedEvent;

      setUp(() async {
        bitcoinReceiveCompletedEvent = Completer();
        liquidReceiveCompletedEvent = Completer();
        swapWatcherService.startWatching();
        _swapSubscription = swapWatcherService.swapSubscription!;
        _swapSubscription.onData((swap) {
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
              print('SOMETHING WENT WRONG');
              print('Wrong swap type saved');
              return;
          }
        });
      });
      test('Create Liquid Swap, Pay and Wait for Completion', () async {
        final swap = await receiveSwapUseCase.execute(
          walletId: instantWallet.id,
          type: SwapType.lightningToLiquid,
          amountSat: 1210,
        );
        print("Pay invoice");
        print(swap.invoice);
        expect(swap, isNotNull);
        final didReceiverComplete = await Future.any(
          [
            liquidReceiveCompletedEvent.future,
          ],
        );
        print("Liquid Swap completed");
        expect(didReceiverComplete, true);
      });
    });
  });
}
