import 'dart:async';

import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/services/payjoin_watcher_service.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/_core/domain/usecases/receive_with_payjoin_use_case.dart';
import 'package:bb_mobile/_core/domain/usecases/send_with_payjoin_use_case.dart';
import 'package:bb_mobile/_utils/constants.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/recover_wallet/domain/usecases/recover_wallet_use_case.dart';
import 'package:bb_mobile/settings/domain/usecases/set_environment_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:payjoin_flutter/src/generated/frb_generated.dart';
import 'package:test/test.dart';

void main() {
  late WalletManagerService walletManagerService;
  late PayjoinWatcherService payjoinWatcherService;
  late ReceiveWithPayjoinUsecase receiveWithPayjoinUsecase;
  late SendWithPayjoinUsecase sendWithPayjoinUsecase;
  late Wallet receiverWallet;
  late Wallet senderWallet;

  // TODO: Change and move these to github secrets so the testnet coins for our integration
  //  tests are not at risk of being used by others.
  const receiverMnemonic =
      'model float claim feature convince exchange truck cream assume fancy swamp offer';
  const senderMnemonic =
      'duty tattoo frown crazy pelican aisle area wrist robot stove taxi material';

  setUpAll(() async {
    await Future.wait([
      Hive.initFlutter(),
      core.init(),
    ]);

    await AppLocator.setup();

    // Make sure we are running in testnet environment
    await locator<SetEnvironmentUsecase>().execute(Environment.testnet);

    walletManagerService = locator<WalletManagerService>();
    payjoinWatcherService = locator<PayjoinWatcherService>();
    receiveWithPayjoinUsecase = locator<ReceiveWithPayjoinUsecase>();
    sendWithPayjoinUsecase = locator<SendWithPayjoinUsecase>();

    receiverWallet = await locator<RecoverWalletUsecase>().execute(
      mnemonicWords: receiverMnemonic.split(' '),
      scriptType: ScriptType.bip84,
    );
    senderWallet = await locator<RecoverWalletUsecase>().execute(
      mnemonicWords: senderMnemonic.split(' '),
      scriptType: ScriptType.bip84,
    );

    debugPrint('Wallets created');
  });

  setUp(() async {
    // Sync the wallets before every other test
    await walletManagerService.syncAll();

    debugPrint('Wallets synced');
  });

  test('Wallets have funds to payjoin', () async {
    final senderBalance = await walletManagerService.getBalance(
      walletId: senderWallet.id,
    );
    final receiverBalance = await walletManagerService.getBalance(
      walletId: receiverWallet.id,
    );
    debugPrint('Sender balance: $senderBalance');
    debugPrint('Receiver balance: $receiverBalance');

    if (senderBalance.totalSat == BigInt.zero) {
      final address = await walletManagerService.getNewAddress(
        walletId: senderWallet.id,
      );
      debugPrint(
        'Send some funds to ${address.address} before running the integration test again',
      );
    }
    if (receiverBalance.totalSat == BigInt.zero) {
      final address = await walletManagerService.getNewAddress(
        walletId: receiverWallet.id,
      );
      debugPrint(
        'Send some funds to ${address.address} before running the integration test again',
      );
    }

    expect(senderBalance.totalSat.toInt(), greaterThan(0));
    expect(receiverBalance.totalSat.toInt(), greaterThan(0));
  });

  group('Payjoin Integration Tests', () {
    group('with one receive and one send', () {
      late StreamSubscription<Payjoin> payjoinSubscription;
      late Completer<bool> payjoinReceiverCompletedEvent;
      late Completer<bool> payjoinSenderCompletedEvent;

      setUp(() async {
        payjoinReceiverCompletedEvent = Completer();
        payjoinSenderCompletedEvent = Completer();

        payjoinSubscription = payjoinWatcherService.payjoins.listen((payjoin) {
          debugPrint('Payjoin event: $payjoin');
          switch (payjoin) {
            case PayjoinReceiver _:
              if (payjoin.status == PayjoinStatus.completed) {
                payjoinReceiverCompletedEvent.complete(true);
              }
            case PayjoinSender _:
              if (payjoin.status == PayjoinStatus.completed) {
                payjoinSenderCompletedEvent.complete(true);
              }
          }
        });
      });

      test('should work', () async {
        // Generate receiver address
        final address = await walletManagerService.getNewAddress(
          walletId: receiverWallet.id,
        );
        debugPrint('Receive address generated: ${address.address}');

        // Start a receiver session
        final payjoin = await receiveWithPayjoinUsecase.execute(
          walletId: receiverWallet.id,
          address: address.address,
          isTestnet: true,
        );
        debugPrint('Payjoin receiver created: $payjoin');

        expect(payjoin.status, PayjoinStatus.started);
        // Check that the payjoin uri is correct
        final pjUri = Uri.parse(payjoin.pjUri);
        expect(pjUri.scheme, 'bitcoin');
        expect(pjUri.path, address.address);
        expect(pjUri.queryParameters.containsKey('pj'), true);
        expect(pjUri.queryParameters['pjos'], '0');

        // Build the psbt with the sender wallet
        const networkFeesSatPerVb = 1000.0;
        final originalPsbt = await walletManagerService.buildPsbt(
          walletId: senderWallet.id,
          address: address.address,
          amountSat: BigInt.from(1000),
          feeRateSatPerVb: networkFeesSatPerVb,
        );

        final payjoinSender = await sendWithPayjoinUsecase.execute(
          walletId: senderWallet.id,
          bip21: pjUri.toString(),
          originalPsbt: originalPsbt,
          networkFeesSatPerVb: networkFeesSatPerVb,
        );
        debugPrint('Payjoin sender created: $payjoinSender');
        expect(payjoinSender.status, PayjoinStatus.requested);

        // Once the request is sent by the sender, it is automatically fetched
        //  by the receiver the next time it polls the payjoin directory.
        //  The receiver will process the request automatically and sends a
        //  payjoin proposal back to the payjoin directory which should complete
        //  the payjoin session for the receiver's side.
        final didReceiverComplete = await Future.any(
          [
            payjoinReceiverCompletedEvent.future,
            Future.delayed(
              const Duration(
                seconds: PayjoinConstants.directoryPollingInterval * 3,
              ),
              () => false,
            ),
          ],
        );
        expect(didReceiverComplete, true);

        // Once the proposal is sent by the receiver, it is automatically fetched
        //  by the sender the next time it polls the payjoin directory.
        // The sender will process the proposal automatically and broadcast the
        //  final transaction to the network which should complete the payjoin
        //  session for the sender's side.
        final didSenderComplete = await Future.any(
          [
            payjoinSenderCompletedEvent.future,
            Future.delayed(
              const Duration(
                seconds: PayjoinConstants.directoryPollingInterval * 3,
              ),
              () => false,
            ),
          ],
        );
        expect(didSenderComplete, true);
      });

      test('should successfully resume after a restart', () {});

      test('should fail if the receiver does not have enough funds', () {});

      test('should fail if the sender does not have enough funds', () {});

      test(
        'should broadcast the original transaction if the payjoin is expired',
        () {},
      );

      test(
        'should broadcast the original transaction if the payjoin fails',
        () {},
      );
      tearDown(() {
        payjoinSubscription.cancel();
      });
    });

    group('with multiple ongoing payjoins', () {});
  });
}
