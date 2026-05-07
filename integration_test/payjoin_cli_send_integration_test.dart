/// End-to-End Interoperability Test: Bull Bitcoin Mobile <-> payjoin-cli
///
/// This test verifies that the mobile app's payjoin receiver implementation is
/// spec-compliant and interoperable with payjoin-cli, the reference
/// implementation from the rust-payjoin project.
///
/// This test is NOT run directly — it is orchestrated by a shell script that
/// reads the BIP21 pjURI printed by this test and passes it to payjoin-cli:
///
///   scripts/payjoin_cli_send_test.sh
///
/// Scenario: mobile as RECEIVER, payjoin-cli as SENDER
///
///   1. This test creates a mobile payjoin receiver, prints the BIP21 pjURI
///      to stdout (prefixed with "PJ_URI:"), then polls for completion.
///   2. The shell script picks up the URI and runs `payjoin-cli send <uri>`.
///   3. payjoin-cli builds an original PSBT and posts it to the directory.
///   4. The mobile receiver's background isolate picks up the request,
///      processes it, contributes inputs, and posts a proposal back.
///   5. payjoin-cli picks up the proposal, signs, and broadcasts.
///   6. This test detects PayjoinStatus.proposed and passes.
///
/// Prerequisites:
///   - Mobile wallet funded with testnet3 tBTC (TEST_ALICE_MNEMONIC in .env)
///   - payjoin-cli wallet funded with testnet3 tBTC (managed by bitcoind)
///
/// Environment variables:
///   TEST_ALICE_MNEMONIC          Mobile wallet mnemonic (needs testnet3 tBTC)
///   PAYJOIN_CLI_SEND_AMOUNT_SAT  Amount in sat (default: 2000)
library;

import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

const _dartDefines = <String, String>{
  'TEST_ALICE_MNEMONIC': String.fromEnvironment('TEST_ALICE_MNEMONIC'),
  'PAYJOIN_CLI_SEND_AMOUNT_SAT':
      String.fromEnvironment('PAYJOIN_CLI_SEND_AMOUNT_SAT'),
};

String _env(String key, {String? fallback}) {
  final dartVal = _dartDefines[key];
  final val = (dartVal != null && dartVal.isNotEmpty)
      ? dartVal
      : Platform.environment[key] ?? dotenv.env[key];
  if (val != null && val.isNotEmpty) return val;
  if (fallback != null) return fallback;
  throw Exception('Required environment variable $key is not set');
}

Future<void> main({bool isInitialized = false}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String mobileWalletMnemonic;
  late int amountSat;

  late WalletRepository walletRepository;
  late WalletAddressRepository addressRepository;
  late PayjoinRepository payjoinRepository;
  late ReceiveWithPayjoinUsecase receiveWithPayjoinUsecase;

  late Wallet mobileWallet;

  setUpAll(() async {
    if (!isInitialized) await Bull.init();

    mobileWalletMnemonic = _env('TEST_ALICE_MNEMONIC');
    amountSat =
        int.parse(_env('PAYJOIN_CLI_SEND_AMOUNT_SAT', fallback: '2000'));

    walletRepository = locator<WalletRepository>();
    addressRepository = locator<WalletAddressRepository>();
    payjoinRepository = locator<PayjoinRepository>();
    receiveWithPayjoinUsecase = locator<ReceiveWithPayjoinUsecase>();

    await locator<SetEnvironmentUsecase>().execute(Environment.testnet);

    final seed = await locator<SeedRepository>().createFromMnemonic(
      mnemonicWords: mobileWalletMnemonic.split(' '),
    );
    mobileWallet = await walletRepository.createWallet(
      seed: seed,
      network: Network.bitcoinTestnet,
      scriptType: ScriptType.bip84,
    );
    debugPrint('[integration] Mobile wallet id: ${mobileWallet.id}');
  });

  setUp(() async {
    await walletRepository.getWallets(sync: true);
    mobileWallet = (await walletRepository.getWallet(mobileWallet.id))!;
    debugPrint('[integration] Balance: ${mobileWallet.balanceSat} sat');
  });

  test(
    'mobile receiver can accept payjoin from payjoin-cli sender',
    () async {
      if (mobileWallet.balanceSat == BigInt.zero) {
        final addr = await addressRepository.generateNewReceiveAddress(
          walletId: mobileWallet.id,
        );
        fail(
          'Mobile wallet has no funds (needs UTXOs to contribute to payjoin). '
          'Send testnet3 tBTC to ${addr.address} and retry.',
        );
      }

      // --- Step 1: create a mobile payjoin receiver ---
      final address = await addressRepository.generateNewReceiveAddress(
        walletId: mobileWallet.id,
      );
      debugPrint('[integration] Receive address: ${address.address}');

      final receiver = await receiveWithPayjoinUsecase.execute(
        walletId: mobileWallet.id,
        address: address.address,
      );
      debugPrint('[integration] Receiver created: ${receiver.id}');
      expect(receiver.status, PayjoinStatus.started);

      final pjUri = receiver.pjUri;
      debugPrint('[integration] pjUri: $pjUri');
      expect(pjUri, contains('pj='));

      // Print the URI on its own line so the shell script can grep for it.
      // ignore: avoid_print
      print('PJ_URI:$pjUri');

      // --- Step 2: wait for the background receiver flow to complete ---
      // The mobile receiver's background isolate automatically:
      //   - polls the directory for the CLI sender's original PSBT
      //   - processes the request, contributes inputs, creates a proposal
      //   - posts the proposal back to the directory
      // We just need to listen for the status change.
      final proposedCompleter = Completer<bool>();
      final payjoinSub = payjoinRepository.payjoinStream.listen((payjoin) {
        debugPrint(
          '[integration] Payjoin event ${payjoin.id}: ${payjoin.status}',
        );
        if (payjoin is PayjoinReceiver &&
            payjoin.id == receiver.id &&
            payjoin.status == PayjoinStatus.proposed &&
            !proposedCompleter.isCompleted) {
          proposedCompleter.complete(true);
        }
      });

      try {
        debugPrint(
          '[integration] Waiting for CLI sender to post request and '
          'mobile receiver to propose...',
        );
        final proposed = await proposedCompleter.future.timeout(
          Duration(seconds: PayjoinConstants.directoryPollingInterval * 40),
          onTimeout: () => false,
        );
        expect(
          proposed,
          isTrue,
          reason:
              'Mobile receiver did not reach proposed status — '
              'CLI sender may not have posted a request in time',
        );
        debugPrint('[integration] Mobile receiver proposed payjoin!');
      } finally {
        await payjoinSub.cancel();
      }
    },
    timeout: Timeout(
      Duration(seconds: PayjoinConstants.directoryPollingInterval * 45),
    ),
  );
}
