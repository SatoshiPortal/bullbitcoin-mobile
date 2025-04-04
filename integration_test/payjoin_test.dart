import 'dart:async';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/services/payjoin_watcher_service.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/build_transaction_usecase.dart';
import 'package:bb_mobile/features/recover_wallet/domain/usecases/recover_wallet_use_case.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:payjoin_flutter/src/generated/frb_generated.dart';
import 'package:test/test.dart';

void main() {
  late WalletManagerService walletManagerService;
  late PayjoinWatcherService payjoinWatcherService;
  late ReceiveWithPayjoinUsecase receiveWithPayjoinUsecase;
  late SendWithPayjoinUsecase sendWithPayjoinUsecase;
  late BuildTransactionUsecase buildTransactionUsecase;
  late Wallet receiverWallet;
  late Wallet senderWallet;

  // TODO: Change and move these to github secrets so the testnet coins for our integration
  //  tests are not at risk of being used by others.
  const senderMnemonic =
      'model float claim feature convince exchange truck cream assume fancy swamp offer';
  const receiverMnemonic =
      'duty tattoo frown crazy pelican aisle area wrist robot stove taxi material';

  setUpAll(() async {
    await Future.wait([
      dotenv.load(isOptional: true),
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
    buildTransactionUsecase = locator<BuildTransactionUsecase>();

    receiverWallet = await locator<RecoverOrCreateWalletUsecase>().execute(
      mnemonicWords: receiverMnemonic.split(' '),
      scriptType: ScriptType.bip84,
    );
    senderWallet = await locator<RecoverOrCreateWalletUsecase>().execute(
      mnemonicWords: senderMnemonic.split(' '),
      scriptType: ScriptType.bip84,
    );

    debugPrint('Wallets created');
    debugPrint('Receiver wallet id: ${receiverWallet.id}');
    debugPrint('Sender wallet id: ${senderWallet.id}');
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
      late Completer<bool> payjoinReceiverProposedEvent;
      late Completer<bool> payjoinSenderCompletedEvent;
      late Completer<bool> payjoinReceiverExpiredEvent;

      setUp(() {
        payjoinReceiverProposedEvent = Completer();
        payjoinSenderCompletedEvent = Completer();
        payjoinReceiverExpiredEvent = Completer();

        payjoinSubscription = payjoinWatcherService.payjoins.listen((payjoin) {
          debugPrint('Payjoin event for ${payjoin.id}: ${payjoin.status}');
          switch (payjoin) {
            case PayjoinReceiver _:
              if (payjoin.status == PayjoinStatus.proposed) {
                payjoinReceiverProposedEvent.complete(true);
              } else if (payjoin.status == PayjoinStatus.expired) {
                payjoinReceiverExpiredEvent.complete(true);
              }
            case PayjoinSender _:
              if (payjoin.status == PayjoinStatus.completed) {
                payjoinSenderCompletedEvent.complete(true);
              }
          }
        });
      });

      test('should work with one receiver and one sender', () async {
        // Generate receiver address
        final address = await walletManagerService.getNewAddress(
          walletId: receiverWallet.id,
        );
        debugPrint('Receive address generated: ${address.address}');

        // Start a receiver session
        final payjoin = await receiveWithPayjoinUsecase.execute(
          walletId: receiverWallet.id,
          address: address.address,
        );
        debugPrint('Payjoin receiver created: ${payjoin.id}');

        expect(payjoin.status, PayjoinStatus.started);
        // Check that the payjoin uri is correct
        final pjUri = Uri.parse(payjoin.pjUri);
        expect(pjUri.scheme, 'bitcoin');
        expect(pjUri.path, address.address);
        expect(pjUri.queryParameters.containsKey('pj'), true);
        expect(pjUri.queryParameters['pjos'], '0');

        // Build the psbt with the sender wallet
        const networkFeesSatPerVb = 1000.0;
        final originalPsbt = await buildTransactionUsecase.execute(
          walletId: senderWallet.id,
          address: address.address,
          amountSat: 1000,
          networkFee: const NetworkFee.relative(networkFeesSatPerVb),
        );

        final payjoinSender = await sendWithPayjoinUsecase.execute(
          walletId: senderWallet.id,
          bip21: pjUri.toString(),
          originalPsbt: originalPsbt.toPsbtBase64(),
          networkFeesSatPerVb: networkFeesSatPerVb,
        );
        debugPrint('Payjoin sender created: ${payjoinSender.id}');
        expect(payjoinSender.status, PayjoinStatus.requested);

        // Once the request is sent by the sender, it is automatically fetched
        //  by the receiver the next time it polls the payjoin directory.
        //  The receiver will process the request automatically and sends a
        //  payjoin proposal back to the payjoin directory which should complete
        //  the payjoin session for the receiver's side.
        final didReceiverPropose = await Future.any(
          [
            payjoinReceiverProposedEvent.future,
            Future.delayed(
              const Duration(
                seconds: PayjoinConstants.directoryPollingInterval * 3,
              ),
              () => false,
            ),
          ],
        );
        expect(didReceiverPropose, true);

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
        'should expire if time to wait for a request is over',
        () async {
          // Make the payjoin receiver expire before it polls the
          //  payjoin directory for the first time.
          const expireAfterSec = PayjoinConstants.directoryPollingInterval - 1;
          // Generate receiver address from receiver wallet
          final address = await walletManagerService.getNewAddress(
            walletId: receiverWallet.id,
          );

          // Start a receiver session with the expiration time
          final payjoin = await receiveWithPayjoinUsecase.execute(
            walletId: receiverWallet.id,
            address: address.address,
            expireAfterSec: expireAfterSec,
          );
          debugPrint('Payjoin receiver created: ${payjoin.id}');

          final didReceiverExpire = await Future.any(
            [
              payjoinReceiverExpiredEvent.future,
              Future.delayed(
                const Duration(
                  seconds: PayjoinConstants.directoryPollingInterval * 2,
                ),
                () => false,
              ),
            ],
          );
          expect(didReceiverExpire, true);
        },
      );

      tearDown(() {
        payjoinSubscription.cancel();
      });
    });

    group('with multiple ongoing payjoins', () {
      const numberOfPayjoins = 2;
      const networkFeesSatPerVb = 500.0;
      final List<String> receiverAddresses = [];
      final List<Uri> payjoinUris = [];
      final Map<String, Completer<bool>> payjoinCompleters = {};
      late StreamSubscription<Payjoin> payjoinSubscription;

      setUp(() {
        payjoinSubscription = payjoinWatcherService.payjoins.listen((payjoin) {
          debugPrint('Payjoin event for ${payjoin.id}: ${payjoin.status}');
          switch (payjoin) {
            case PayjoinReceiver _:
              if (payjoin.status == PayjoinStatus.proposed) {
                // Complete the receiver side when it has send a proposal
                payjoinCompleters[payjoin.id]!.complete(true);
              }
            case PayjoinSender _:
              if (payjoin.status == PayjoinStatus.completed) {
                payjoinCompleters[payjoin.id]!.complete(true);
              }
          }
        });
      });

      group(
        "and enough utxo's",
        () {
          test('should have wallets with enough utxos', () async {
            // Make sure the wallets have a different utxo for every payjoin
            final receiverUtxos = await walletManagerService.getUnspentUtxos(
              walletId: receiverWallet.id,
            );
            final senderUtxos = await walletManagerService.getUnspentUtxos(
              walletId: senderWallet.id,
            );
            debugPrint('Receiver utxos: ${receiverUtxos.length}');
            debugPrint('Sender utxos: ${senderUtxos.length}');
            if (receiverUtxos.length < numberOfPayjoins) {
              final address = await walletManagerService.getNewAddress(
                walletId: receiverWallet.id,
              );
              debugPrint(
                'Send some utxos to ${address.address} before running the integration test again',
              );
            }
            if (senderUtxos.length < numberOfPayjoins) {
              final address = await walletManagerService.getNewAddress(
                walletId: senderWallet.id,
              );
              debugPrint(
                'Send some utxos to ${address.address} before running the integration test again',
              );
            }
            expect(
              receiverUtxos.length,
              greaterThanOrEqualTo(numberOfPayjoins),
            );
            expect(senderUtxos.length, greaterThanOrEqualTo(numberOfPayjoins));
          });

          test('should work with multiple receivers and senders', () async {
            // Set up multiple receiver sessions
            for (int i = 0; i < numberOfPayjoins; i++) {
              // Generate receiver address
              final address = await walletManagerService.getNewAddress(
                walletId: receiverWallet.id,
              );
              debugPrint('Receive address generated: ${address.address}');

              // Start a receiver session
              final payjoin = await receiveWithPayjoinUsecase.execute(
                walletId: receiverWallet.id,
                address: address.address,
              );
              debugPrint('Payjoin receiver created: ${payjoin.id}');

              expect(payjoin.status, PayjoinStatus.started);
              // Check that the payjoin uri is correct
              final pjUri = Uri.parse(payjoin.pjUri);
              expect(pjUri.scheme, 'bitcoin');
              expect(pjUri.path, address.address);
              expect(pjUri.queryParameters.containsKey('pj'), true);
              expect(pjUri.queryParameters['pjos'], '0');

              // Cache the address and payjoin uri
              receiverAddresses.add(address.address);
              payjoinUris.add(pjUri);
              // Set a completer to check it completes successfully
              payjoinCompleters[payjoin.id] = Completer();
            }

            // Set up multiple sender sessions
            for (int i = 0; i < numberOfPayjoins; i++) {
              // Build the psbt with the sender wallet
              final originalPsbt = await buildTransactionUsecase.execute(
                walletId: senderWallet.id,
                address: receiverAddresses[i],
                amountSat: 1000,
                networkFee: const NetworkFee.relative(networkFeesSatPerVb),
              );

              final payjoinSender = await sendWithPayjoinUsecase.execute(
                walletId: senderWallet.id,
                bip21: payjoinUris[i].toString(),
                originalPsbt: originalPsbt.toPsbtBase64(),
                networkFeesSatPerVb: networkFeesSatPerVb,
              );
              debugPrint('Payjoin sender created: ${payjoinSender.id}');
              expect(payjoinSender.status, PayjoinStatus.requested);

              // Store completers for the sender sessions
              payjoinCompleters[payjoinSender.id] = Completer();
            }

            final didAllComplete = await Future.any(
              [
                Future.wait(payjoinCompleters.values.map((e) => e.future)).then(
                  (results) => results.every(
                    (completed) => completed == true, // Ensure all completed
                  ),
                ),
                Future.delayed(
                  const Duration(
                    seconds: PayjoinConstants.directoryPollingInterval *
                        3 *
                        numberOfPayjoins,
                  ),
                  () => false,
                ),
              ],
            );
            expect(didAllComplete, true);
          });
        },
        timeout: const Timeout(
          Duration(
            minutes: PayjoinConstants.directoryPollingInterval *
                3 *
                numberOfPayjoins,
          ),
        ),
      );

      tearDown(() {
        payjoinSubscription.cancel();
      });
    });
  });
}
