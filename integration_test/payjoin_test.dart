import 'dart:io' show Directory, Platform;

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' hide ScriptType;

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  Directory? payjoinDirectory;
  if (!isInitialized) {
    payjoinDirectory = await Directory.systemTemp.createTemp(
      'payjoin-integration-',
    );
    await Bull.init(
      payjoinDatabasePath: '${payjoinDirectory.path}/payjoin.sqlite',
    );
  }

  final walletRepository = locator<WalletRepository>();
  final seedRepository = locator<SeedRepository>();
  final addressRepository = locator<WalletAddressRepository>();
  final utxoRepository = locator<WalletUtxoRepository>();
  final receiverRole = locator<PayjoinReceiver>();
  final senderRole = locator<PayjoinSender>();
  final sessions = locator<PayjoinSessions>();
  final policy = locator<PayjoinPolicyAccess>();
  final prepareBitcoinSend = locator<PrepareBitcoinSendUsecase>();
  final signBitcoinTx = locator<SignBitcoinTxUsecase>();
  final broadcastBitcoinTx = locator<BroadcastBitcoinTransactionUsecase>();

  late Wallet receiverWallet;
  late Wallet senderWallet;

  Future<void> consolidateUtxos(String walletId) async {
    final utxos = await utxoRepository.getWalletUtxos(walletId: walletId);
    if (utxos.length <= 1) return;
    final address = await addressRepository.generateNewReceiveAddress(
      walletId: walletId,
    );
    final prepared = await prepareBitcoinSend.execute(
      walletId: walletId,
      address: address.address,
      drain: true,
      networkFee: NetworkFee.relativeFromSatPerVbyte(1000),
    );
    final signed = await signBitcoinTx.execute(
      psbt: prepared.unsignedPsbt,
      walletId: walletId,
    );
    await broadcastBitcoinTx.execute(signed.signedPsbt, isPsbt: true);
    await Future<void>.delayed(const Duration(seconds: 3));
    await walletRepository.getWallets(sync: true);
  }

  const aliceDefine = String.fromEnvironment('TEST_ALICE_MNEMONIC');
  const bobDefine = String.fromEnvironment('TEST_BOB_MNEMONIC');
  final receiverMnemonic = aliceDefine.isNotEmpty
      ? aliceDefine
      : Platform.environment['TEST_ALICE_MNEMONIC'];
  final senderMnemonic = bobDefine.isNotEmpty
      ? bobDefine
      : Platform.environment['TEST_BOB_MNEMONIC'];

  // The test is aggregated into CI's all_test.dart, where the funded-wallet
  // fixtures are not available: skip gracefully there instead of failing the
  // whole integration job, and run for real wherever the mnemonics are set.
  final hasFixtures =
      receiverMnemonic != null &&
      receiverMnemonic.isNotEmpty &&
      senderMnemonic != null &&
      senderMnemonic.isNotEmpty;
  const fixtureSkip =
      'requires TEST_ALICE_MNEMONIC and TEST_BOB_MNEMONIC (funded testnet wallets)';

  setUpAll(() async {
    await locator<SetEnvironmentUsecase>().execute(Environment.testnet);
    final enabled = await policy.setEnabled(true);
    if (enabled case Err(:final failure)) throw failure;

    final receiverSeed = await seedRepository.createFromMnemonic(
      mnemonicWords: receiverMnemonic!.split(' '),
    );
    final senderSeed = await seedRepository.createFromMnemonic(
      mnemonicWords: senderMnemonic!.split(' '),
    );
    receiverWallet = await walletRepository.createWallet(
      seed: receiverSeed,
      network: Network.bitcoinTestnet,
      scriptType: ScriptType.bip84,
    );
    senderWallet = await walletRepository.createWallet(
      seed: senderSeed,
      network: Network.bitcoinTestnet,
      scriptType: ScriptType.bip84,
    );
  });

  tearDownAll(() async {
    if (payjoinDirectory == null) return;
    if (locator.isRegistered<PayjoinLifecycle>()) {
      await locator<PayjoinLifecycle>().dispose();
    }
    await payjoinDirectory.delete(recursive: true);
  });

  setUp(() async {
    await walletRepository.getWallets(sync: true);
  });

  test(
    'resumes an ongoing Payjoin after an app restart',
    () {},
    skip: 'Requires an integration harness that restarts the app and DB',
  );

  test(
    'rejects a Payjoin when the receiver has insufficient funds',
    () {},
    skip: 'Requires a funded sender and an underfunded receiver fixture',
  );

  test(
    'rejects a Payjoin when the sender has insufficient funds',
    () {},
    skip: 'Requires an underfunded sender fixture',
  );

  test(
    'supports concurrent Payjoins backed by distinct UTXOs',
    () {},
    skip:
        'Requires two UTXOs per wallet; the funded happy-path fixture '
        'currently consolidates them to avoid the upstream receiver '
        'selection bug',
  );

  test(
    'funded testnet wallets complete a Payjoin',
    skip: hasFixtures ? null : fixtureSkip,
    () async {
      receiverWallet = (await walletRepository.getWallet(receiverWallet.id))!;
      senderWallet = (await walletRepository.getWallet(senderWallet.id))!;
      expect(receiverWallet.balanceSat, greaterThan(BigInt.zero));
      expect(senderWallet.balanceSat, greaterThan(BigInt.zero));

      await consolidateUtxos(receiverWallet.id);
      await consolidateUtxos(senderWallet.id);

      final address = await addressRepository.generateNewReceiveAddress(
        walletId: receiverWallet.id,
      );
      final receiverResult = await receiverRole.start(
        StartPayjoinReceiver(
          walletId: receiverWallet.id,
          network: BitcoinNetwork.testnet,
          address: address.address,
          amount: Sats.fromInt(10000),
        ),
      );
      final receiver = switch (receiverResult) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
      final uri = Uri.parse(receiver.pjUri);
      expect(uri.scheme, 'bitcoin');
      expect(uri.path, address.address);
      expect(uri.queryParameters, contains('pj'));

      const feeRate = 1000.0;
      final prepared = await prepareBitcoinSend.execute(
        walletId: senderWallet.id,
        address: address.address,
        amountSat: 10000,
        networkFee: NetworkFee.relativeFromSatPerVbyte(feeRate),
      );
      final senderResult = await senderRole.start(
        StartPayjoinSender(
          walletId: senderWallet.id,
          network: BitcoinNetwork.testnet,
          bip21Uri: receiver.pjUri,
          unsignedOriginalPsbt: prepared.unsignedPsbt,
          amount: Sats.fromInt(10000),
          feeRate: FeeRate(feeRate),
        ),
      );
      final sender = switch (senderResult) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };

      final completed = await sessions
          .watch(sessionIds: {sender.id})
          .where(
            (result) => switch (result) {
              Ok(:final value) => value.status == PayjoinStatus.completed,
              Err() => false,
            },
          )
          .first
          .timeout(const Duration(seconds: 300));
      expect(completed, isA<Ok<PayjoinSession, PayjoinFailure>>());
    },
    timeout: const Timeout(Duration(seconds: 330)),
  );

  test(
    'a receiver expires when no sender submits a request',
    skip: hasFixtures ? null : fixtureSkip,
    () async {
      final address = await addressRepository.generateNewReceiveAddress(
        walletId: receiverWallet.id,
      );
      final receiverResult = await receiverRole.start(
        StartPayjoinReceiver(
          walletId: receiverWallet.id,
          network: BitcoinNetwork.testnet,
          address: address.address,
          amount: Sats.fromInt(10000),
          expiresAt: DateTime.now().add(
            PayjoinPolicy.minimumSessionLifetime + const Duration(seconds: 1),
          ),
        ),
      );
      final receiver = switch (receiverResult) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };

      final expired = await sessions
          .watch(sessionIds: {receiver.id})
          .where(
            (result) => switch (result) {
              Ok(:final value) => value.status == PayjoinStatus.expired,
              Err() => false,
            },
          )
          .first
          .timeout(const Duration(seconds: 240));

      expect(expired, isA<Ok<PayjoinSession, PayjoinFailure>>());
    },
    timeout: const Timeout(Duration(seconds: 270)),
  );
}
