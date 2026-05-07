/// End-to-End Interoperability Test: Bull Bitcoin Mobile <-> payjoin-cli
///
/// This test verifies that the mobile app's payjoin sender implementation is
/// spec-compliant and interoperable with payjoin-cli, the reference
/// implementation from the rust-payjoin project.
///
/// This test is NOT run directly — it is orchestrated by a shell script that
/// starts payjoin-cli and passes the BIP21 pjURI to this test via an env var:
///
///   scripts/payjoin_cli_receive_test.sh
///
/// Scenario: payjoin-cli as RECEIVER, mobile as SENDER
///
///   1. payjoin-cli `receive <sats>` is started by the script, which prints the
///      BIP21 pjURI and long-polls the directory for a request.
///   2. This test reads the pjURI from PJ_BIP21_URI, builds a PSBT with the
///      mobile wallet, and starts a mobile sender session.
///   3. payjoin-cli picks up the request, processes it, and posts a proposal
///      back to the directory.
///   4. The mobile sender's automatic poll loop picks up the proposal, signs
///      and broadcasts the final tx, reaching PayjoinStatus.completed.
///
/// Prerequisites:
///   - Mobile wallet funded with testnet3 tBTC (TEST_ALICE_MNEMONIC)
///   - payjoin-cli receiver already running (managed by the shell script)
///
/// Environment variables (passed via --dart-define / --dart-define-from-file):
///   TEST_ALICE_MNEMONIC          Mobile wallet mnemonic (needs testnet3 tBTC)
///   PJ_BIP21_URI                 BIP21 pjURI from payjoin-cli (set by script)
///   PAYJOIN_CLI_SEND_AMOUNT_SAT  Amount in sat (default: 2000)
library;

import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

const _dartDefines = <String, String>{
  'PJ_BIP21_URI': String.fromEnvironment('PJ_BIP21_URI'),
  'TEST_ALICE_MNEMONIC': String.fromEnvironment('TEST_ALICE_MNEMONIC'),
  'PAYJOIN_CLI_SEND_AMOUNT_SAT':
      String.fromEnvironment('PAYJOIN_CLI_SEND_AMOUNT_SAT'),
};

String _env(String key, {String? fallback}) {
  final dartVal = _dartDefines[key];
  final val = (dartVal != null && dartVal.isNotEmpty)
      ? dartVal
      : Platform.environment[key];
  if (val != null && val.isNotEmpty) return val;
  if (fallback != null) return fallback;
  throw Exception('Required environment variable $key is not set');
}

Future<void> main({bool isInitialized = false}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String mobileWalletMnemonic;
  late String pjBip21Uri;
  late int amountSat;
  const networkFeesSatPerVb = 2.0;

  late WalletRepository walletRepository;
  late WalletAddressRepository addressRepository;
  late PayjoinRepository payjoinRepository;
  late SendWithPayjoinUsecase sendWithPayjoinUsecase;
  late PrepareBitcoinSendUsecase prepareBitcoinSendUsecase;

  late Wallet mobileWallet;

  setUpAll(() async {
    if (!isInitialized) await Bull.init();

    mobileWalletMnemonic = _env('TEST_ALICE_MNEMONIC');
    pjBip21Uri = _env('PJ_BIP21_URI');
    amountSat =
        int.parse(_env('PAYJOIN_CLI_SEND_AMOUNT_SAT', fallback: '2000'));

    walletRepository = locator<WalletRepository>();
    addressRepository = locator<WalletAddressRepository>();
    payjoinRepository = locator<PayjoinRepository>();
    sendWithPayjoinUsecase = locator<SendWithPayjoinUsecase>();
    prepareBitcoinSendUsecase = locator<PrepareBitcoinSendUsecase>();

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
    'mobile sender can pay to payjoin-cli receiver',
    () async {
      if (mobileWallet.balanceSat == BigInt.zero) {
        final addr = await addressRepository.generateNewReceiveAddress(
          walletId: mobileWallet.id,
        );
        fail(
          'Mobile wallet has no funds. '
          'Send testnet3 tBTC to ${addr.address} and retry.',
        );
      }

      debugPrint('[integration] Using pjURI: $pjBip21Uri');
      expect(pjBip21Uri, contains('pj='));

      final senderCompletedCompleter = Completer<bool>();
      final payjoinSub = payjoinRepository.payjoinStream.listen((payjoin) {
        debugPrint(
          '[integration] Payjoin event ${payjoin.id}: ${payjoin.status}',
        );
        if (payjoin is PayjoinSender &&
            payjoin.status == PayjoinStatus.completed &&
            !senderCompletedCompleter.isCompleted) {
          senderCompletedCompleter.complete(true);
        }
      });

      try {
        final preparedSend = await prepareBitcoinSendUsecase.execute(
          walletId: mobileWallet.id,
          address: Uri.parse(pjBip21Uri).path,
          amountSat: amountSat,
          networkFee: const NetworkFee.relative(networkFeesSatPerVb),
          ignoreUnspendableInputs: false,
        );

        final sender = await sendWithPayjoinUsecase.execute(
          walletId: mobileWallet.id,
          isTestnet: mobileWallet.isTestnet,
          bip21: pjBip21Uri,
          unsignedOriginalPsbt: preparedSend.unsignedPsbt,
          amountSat: amountSat,
          networkFeesSatPerVb: networkFeesSatPerVb,
        );
        debugPrint('[integration] Mobile sender created: ${sender.id}');
        expect(sender.status, PayjoinStatus.requested);

        // Sender's background poll loop posts the original PSBT, picks up the
        // CLI's proposal, signs it, and broadcasts — all driven by the
        // PdkPayjoinDatasource session loop. We just wait for completion.
        final completed = await senderCompletedCompleter.future.timeout(
          Duration(seconds: PayjoinConstants.directoryPollingInterval * 20),
          onTimeout: () => false,
        );
        expect(
          completed,
          isTrue,
          reason: 'Mobile sender did not reach completed status — '
              'CLI receiver may not have posted a proposal in time',
        );
      } finally {
        await payjoinSub.cancel();
      }
    },
    timeout: const Timeout(
      Duration(seconds: PayjoinConstants.directoryPollingInterval * 25),
    ),
  );
}
