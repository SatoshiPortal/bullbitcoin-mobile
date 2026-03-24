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
///   4. The mobile sender polls, picks up the proposal, signs and broadcasts
///      the final tx, reaching PayjoinStatus.completed.
///
/// Prerequisites:
///   - Mobile wallet funded with testnet3 tBTC (TEST_ALICE_MNEMONIC in .env)
///   - payjoin-cli receiver already running (managed by the shell script)
///
/// Environment variables:
///   TEST_ALICE_MNEMONIC   Mobile wallet mnemonic (needs testnet3 tBTC)
///   PJ_BIP21_URI          BIP21 pjURI from payjoin-cli (set by script)
library;

import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/domain/ports/electrum_server_port.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/pdk_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

// Compile-time defines passed via --dart-define (required for device-based tests
// where Platform.environment is unavailable, e.g. Android).
const _dartDefines = <String, String>{
  'PJ_BIP21_URI': String.fromEnvironment('PJ_BIP21_URI'),
  'TEST_ALICE_MNEMONIC': String.fromEnvironment('TEST_ALICE_MNEMONIC'),
  'TEST_BOB_MNEMONIC': String.fromEnvironment('TEST_BOB_MNEMONIC'),
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
  // NOTE: Bull.init() and locator<> calls are deferred to setUpAll() so that
  // the flutter-test VM "loading" pre-check can call main() on the Linux host
  // without trying to dlopen libark_wallet.so (which only exists on Android).

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

      final parsedUri = Uri.parse(pjBip21Uri);
      final recipientAddress = parsedUri.path;

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

      final localDatasource = locator<LocalPayjoinDatasource>();
      final bitcoinWalletRepository = locator<BitcoinWalletRepository>();
      final blockchain = locator<BdkBitcoinBlockchainDatasource>();
      final dio = Dio();
      const electrumServer = ElectrumServer(
        url: ApiServiceConstants.publicElectrumTestUrlTwo,
        priority: 1,
        retry: 5,
        timeout: 5,
        stopGap: 20,
        validateDomain: true,
        isCustom: false,
      );

      try {
        final preparedSend = await prepareBitcoinSendUsecase.execute(
          walletId: mobileWallet.id,
          address: recipientAddress,
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

        // --- Step 1: post the original PSBT to the directory ---
        final senderModel = await localDatasource.fetchSender(sender.id);
        expect(senderModel, isNotNull, reason: 'Sender model not found in DB');
        final payjoinSender = Sender.fromJson(json: senderModel!.sender);

        debugPrint('[integration] Posting payjoin request to directory...');
        final getContext = await PdkPayjoinDatasource.request(
          sender: payjoinSender,
          dio: dio,
        );
        debugPrint('[integration] Request posted, polling for CLI proposal...');

        // --- Step 2: poll until the CLI receiver posts a proposal ---
        String? proposalPsbt;
        for (int i = 0; i < 18; i++) {
          proposalPsbt = await PdkPayjoinDatasource.getProposalPsbt(
            context: getContext,
            dio: dio,
          );
          if (proposalPsbt != null) break;
          debugPrint(
              '[integration] No proposal yet, retrying (${i + 1}/18)...');
          await Future.delayed(
            const Duration(seconds: PayjoinConstants.directoryPollingInterval),
          );
        }
        expect(
          proposalPsbt,
          isNotNull,
          reason: 'CLI did not post a payjoin proposal in time',
        );
        debugPrint('[integration] Received CLI proposal, signing...');

        // --- Step 3: sign the proposal PSBT and broadcast ---
        final signedProposalPsbt = await bitcoinWalletRepository.signPsbt(
          proposalPsbt!,
          walletId: mobileWallet.id,
        );
        debugPrint('[integration] Proposal signed, broadcasting...');

        final txId = await blockchain.broadcastPsbt(
          signedProposalPsbt,
          electrumServer: electrumServer,
        );
        debugPrint('[integration] Payjoin tx broadcast: $txId');
        expect(txId, isNotEmpty, reason: 'Broadcast returned empty txId');
      } finally {
        await payjoinSub.cancel();
        dio.close();
      }
    },
    timeout: const Timeout(
      Duration(seconds: PayjoinConstants.directoryPollingInterval * 20),
    ),
  );
}
