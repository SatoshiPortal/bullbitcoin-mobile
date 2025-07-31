import 'dart:async';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;
import 'package:test/test.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  late Wallet receiverWallet;
  late Wallet senderWallet;

  final walletRepository = locator<WalletRepository>();
  final addressRepository = locator<WalletAddressRepository>();
  final utxoRepository = locator<WalletUtxoRepository>();
  final payjoinRepository = locator<PayjoinRepository>();
  final receiveWithPayjoinUsecase = locator<ReceiveWithPayjoinUsecase>();
  final sendWithPayjoinUsecase = locator<SendWithPayjoinUsecase>();
  final prepareBitcoinSendUsecase = locator<PrepareBitcoinSendUsecase>();

  final receiverMnemonic = dotenv.env['TEST_ALICE_MNEMONIC'];
  final senderMnemonic = dotenv.env['TEST_BOB_MNEMONIC'];

  if (receiverMnemonic == null || receiverMnemonic.isEmpty) {
    throw Exception('TEST_ALICE_MNEMONIC environment variable is not set');
  }
  if (senderMnemonic == null || senderMnemonic.isEmpty) {
    throw Exception('TEST_BOB_MNEMONIC environment variable is not set');
  }

  setUpAll(() async {
    await locator<SetEnvironmentUsecase>().execute(Environment.testnet);

    final receiverSeedModel = SeedModel.mnemonic(
      mnemonicWords: receiverMnemonic.split(' '),
    );
    final senderSeedModel = SeedModel.mnemonic(
      mnemonicWords: senderMnemonic.split(' '),
    );
    receiverWallet = await walletRepository.createWallet(
      seed: receiverSeedModel.toEntity(),
      network: Network.bitcoinTestnet,
      scriptType: ScriptType.bip84,
    );
    senderWallet = await walletRepository.createWallet(
      seed: senderSeedModel.toEntity(),
      network: Network.bitcoinTestnet,
      scriptType: ScriptType.bip84,
    );

    debugPrint('Wallets created');
    debugPrint('Receiver wallet id: ${receiverWallet.id}');
    debugPrint('Sender wallet id: ${senderWallet.id}');
  });

  setUp(() async {
    // Sync the wallets before every other test
    await walletRepository.getWallets(sync: true);

    debugPrint('Wallets synced');
  });

  test('Wallets have funds to payjoin', () async {
    senderWallet = (await walletRepository.getWallet(senderWallet.id))!;
    final senderBalance = senderWallet.balanceSat;
    receiverWallet = (await walletRepository.getWallet(receiverWallet.id))!;
    final receiverBalance = receiverWallet.balanceSat;
    debugPrint('Sender balance: $senderBalance');
    debugPrint('Receiver balance: $receiverBalance');

    if (senderBalance == BigInt.zero) {
      final address = await addressRepository.getNewReceiveAddress(
        walletId: senderWallet.id,
      );
      debugPrint(
        'Send some funds to ${address.address} before running the integration test again',
      );
    }
    if (receiverBalance == BigInt.zero) {
      final address = await addressRepository.getNewReceiveAddress(
        walletId: receiverWallet.id,
      );
      debugPrint(
        'Send some funds to ${address.address} before running the integration test again',
      );
    }

    expect(senderBalance.toInt(), greaterThan(0));
    expect(receiverBalance.toInt(), greaterThan(0));
  });

  group('Payjoin Integration Tests', () {
    group('with one receive and one send', () {
      late StreamSubscription<dynamic> payjoinSubscription;
      late Completer<bool> payjoinReceiverProposedEvent;
      late Completer<bool> payjoinSenderCompletedEvent;
      late Completer<bool> payjoinReceiverExpiredEvent;

      setUp(() {
        payjoinReceiverProposedEvent = Completer();
        payjoinSenderCompletedEvent = Completer();
        payjoinReceiverExpiredEvent = Completer();

        payjoinSubscription = payjoinRepository.payjoinStream.listen((payjoin) {
          debugPrint('Payjoin event for ${payjoin.id}: ${payjoin.status}');

          if (payjoin is PayjoinReceiver) {
            if (payjoin.status == PayjoinStatus.proposed) {
              payjoinReceiverProposedEvent.complete(true);
            } else if (payjoin.status == PayjoinStatus.expired) {
              payjoinReceiverExpiredEvent.complete(true);
            }
          } else if (payjoin is PayjoinSender) {
            if (payjoin.status == PayjoinStatus.completed) {
              payjoinSenderCompletedEvent.complete(true);
            }
          }
        });
      });

      test('should work with one receiver and one sender', () async {
        // Generate receiver address
        final address = await addressRepository.getNewReceiveAddress(
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

        // Build the psbt with the sender wallet
        const amountSat = 10000;
        const networkFeesSatPerVb = 1000.0;
        final preparedBitcoinSend = await prepareBitcoinSendUsecase.execute(
          walletId: senderWallet.id,
          address: address.address,
          amountSat: 10000,
          networkFee: const NetworkFee.relative(networkFeesSatPerVb),
          ignoreUnspendableInputs: false,
        );

        final payjoinSender = await sendWithPayjoinUsecase.execute(
          walletId: senderWallet.id,
          isTestnet: senderWallet.isTestnet,
          bip21: pjUri.toString(),
          unsignedOriginalPsbt: preparedBitcoinSend.unsignedPsbt,
          amountSat: amountSat,
          networkFeesSatPerVb: networkFeesSatPerVb,
        );
        debugPrint('Payjoin sender created: ${payjoinSender.id}');
        expect(payjoinSender.status, PayjoinStatus.requested);

        // Once the request is sent by the sender, it is automatically fetched
        //  by the receiver the next time it polls the payjoin directory.
        //  The receiver will process the request automatically and sends a
        //  payjoin proposal back to the payjoin directory which should complete
        //  the payjoin session for the receiver's side.
        final didReceiverPropose = await Future.any([
          payjoinReceiverProposedEvent.future,
          Future.delayed(
            const Duration(
              seconds: PayjoinConstants.directoryPollingInterval * 3,
            ),
            () => false,
          ),
        ]);
        expect(didReceiverPropose, true);

        // Once the proposal is sent by the receiver, it is automatically fetched
        //  by the sender the next time it polls the payjoin directory.
        // The sender will process the proposal automatically and broadcast the
        //  final transaction to the network which should complete the payjoin
        //  session for the sender's side.
        final didSenderComplete = await Future.any([
          payjoinSenderCompletedEvent.future,
          Future.delayed(
            const Duration(
              seconds: PayjoinConstants.directoryPollingInterval * 3,
            ),
            () => false,
          ),
        ]);
        expect(didSenderComplete, true);
      });

      test('should successfully resume after a restart', () {});

      test('should fail if the receiver does not have enough funds', () {});

      test('should fail if the sender does not have enough funds', () {});

      test('should expire if time to wait for a request is over', () async {
        // Make the payjoin receiver expire before it polls the
        //  payjoin directory for the first time.
        const expireAfterSec = PayjoinConstants.directoryPollingInterval - 1;
        // Generate receiver address from receiver wallet
        final address = await addressRepository.getNewReceiveAddress(
          walletId: receiverWallet.id,
        );

        // Start a receiver session with the expiration time
        final payjoin = await receiveWithPayjoinUsecase.execute(
          walletId: receiverWallet.id,
          address: address.address,
          expireAfterSec: expireAfterSec,
        );
        debugPrint('Payjoin receiver created: ${payjoin.id}');

        final didReceiverExpire = await Future.any([
          payjoinReceiverExpiredEvent.future,
          Future.delayed(
            const Duration(
              seconds: PayjoinConstants.directoryPollingInterval * 2,
            ),
            () => false,
          ),
        ]);
        expect(didReceiverExpire, true);
      });

      tearDown(() {
        payjoinSubscription.cancel();
      });
    });

    group('with multiple ongoing payjoins', () {
      const numberOfPayjoins = 2;
      final Map<String, Completer<bool>> payjoinCompleters = {};
      late StreamSubscription<dynamic> payjoinSubscription;

      setUp(() {
        payjoinSubscription = payjoinRepository.payjoinStream.listen((payjoin) {
          debugPrint('Payjoin event for ${payjoin.id}: ${payjoin.status}');

          if (payjoin is PayjoinReceiver) {
            if (payjoin.status == PayjoinStatus.proposed) {
              // Complete the receiver side when it has send a proposal
              payjoinCompleters[payjoin.id]!.complete(true);
            }
          } else if (payjoin is PayjoinSender) {
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
            final receiverUtxos = await utxoRepository.getWalletUtxos(
              walletId: receiverWallet.id,
            );
            final senderUtxos = await utxoRepository.getWalletUtxos(
              walletId: senderWallet.id,
            );
            debugPrint('Receiver utxos: ${receiverUtxos.length}');
            debugPrint('Sender utxos: ${senderUtxos.length}');
            if (receiverUtxos.length < numberOfPayjoins) {
              final address = await addressRepository.getNewReceiveAddress(
                walletId: receiverWallet.id,
              );
              debugPrint(
                'Send some utxos to ${address.address} before running the integration test again',
              );
            }
            if (senderUtxos.length < numberOfPayjoins) {
              final address = await addressRepository.getNewReceiveAddress(
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

          // TODO: Fix this test
          // test('should work with multiple receivers and senders', () async {
          // const networkFeesSatPerVb = 1000.0;
          // final List<String> receiverAddresses = [];
          // final List<Uri> payjoinUris = [];

          //   // Set up multiple receiver sessions
          //   for (int i = 0; i < numberOfPayjoins; i++) {
          //     // Generate receiver address
          //     final address = await addressRepository.getNewReceiveAddress(
          //       walletId: receiverWallet.id,
          //     );
          //     debugPrint('Receive address generated: ${address.address}');

          //     // Start a receiver session
          //     final payjoin = await receiveWithPayjoinUsecase.execute(
          //       walletId: receiverWallet.id,
          //       address: address.address,
          //     );
          //     debugPrint('Payjoin receiver created: ${payjoin.id}');

          //     expect(payjoin.status, PayjoinStatus.started);
          //     // Check that the payjoin uri is correct
          //     final pjUri = Uri.parse(payjoin.pjUri);
          //     expect(pjUri.scheme, 'bitcoin');
          //     expect(pjUri.path, address.address);
          //     expect(pjUri.queryParameters.containsKey('pj'), true);

          //     // Cache the address and payjoin uri
          //     receiverAddresses.add(address.address);
          //     payjoinUris.add(pjUri);
          //     // Set a completer to check it completes successfully
          //     payjoinCompleters[payjoin.id] = Completer();
          //   }

          //   const amountSat = 1000;
          //   // Set up multiple sender sessions
          //   for (int i = 0; i < numberOfPayjoins; i++) {
          //     // Build the psbt with the sender wallet
          //     final preparedBitcoinSend = await prepareBitcoinSendUsecase
          //         .execute(
          //           walletId: senderWallet.id,
          //           address: receiverAddresses[i],
          //           amountSat: amountSat,
          //           networkFee: const NetworkFee.relative(networkFeesSatPerVb),
          //           ignoreUnspendableInputs: false,
          //         );

          //     final payjoinSender = await sendWithPayjoinUsecase.execute(
          //       walletId: senderWallet.id,
          //       isTestnet: senderWallet.isTestnet,
          //       bip21: payjoinUris[i].toString(),
          //       unsignedOriginalPsbt: preparedBitcoinSend.unsignedPsbt,
          //       amountSat: amountSat,
          //       networkFeesSatPerVb: networkFeesSatPerVb,
          //     );
          //     debugPrint('Payjoin sender created: ${payjoinSender.id}');
          //     expect(payjoinSender.status, PayjoinStatus.requested);

          //     // Store completers for the sender sessions
          //     payjoinCompleters[payjoinSender.id] = Completer();
          //   }

          //   final didAllComplete = await Future.any([
          //     Future.wait(payjoinCompleters.values.map((e) => e.future)).then(
          //       (results) => results.every(
          //         (completed) => completed == true, // Ensure all completed
          //       ),
          //     ),
          //     Future.delayed(
          //       const Duration(
          //         seconds:
          //             PayjoinConstants.directoryPollingInterval *
          //             3 *
          //             numberOfPayjoins,
          //       ),
          //       () => false,
          //     ),
          //   ]);
          //   expect(didAllComplete, true);
          // });
        },
        timeout: const Timeout(
          Duration(
            minutes:
                PayjoinConstants.directoryPollingInterval *
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
