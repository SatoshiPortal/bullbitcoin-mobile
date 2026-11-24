import 'dart:io' show Platform;

import 'package:address_view/address_view.dart';
import 'package:bb_mobile/init.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart' show SecretsInventory;
import 'package:spend/payjoin.dart';
import 'package:spend/spend.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart' show WalletNativeRuntime;

import 'developer_network.dart';
import 'funded_testnet_wallet.dart';
import 'initialization_result.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) {
    requireSuccessfulBullInitialization(await Bull.init());
  }

  late final AddressView addresses;
  late final PayjoinReceiver receiverRole;
  late final PayjoinSender senderRole;
  late final PayjoinSessions sessions;
  late final PayjoinPolicyAccess policy;
  late final Spend spend;

  late WalletKey receiverKey;
  late WalletKey senderKey;
  late Wallet receiverWallet;
  late Wallet senderWallet;
  PayjoinPolicy? previousPayjoinPolicy;

  /// Fee rate for every transaction this fixture broadcasts, in sat/vB.
  ///
  /// This used to be 1000. Nothing needed it: none of the assertions below wait
  /// for a confirmation — the happy path waits for `PayjoinStatus.completed`,
  /// which is the protocol exchange, not a block. What it did do was burn the
  /// fixture wallets. A ~250 vB payjoin plus two drain-consolidations cost on
  /// the order of half a million sats per run, on every run, of every PR in the
  /// repository. The wallets emptied faster than anyone could refill them, and
  /// once the balance fell just below what the next transaction needed, this
  /// test failed and turned every open PR red — the failure that sent us
  /// looking here in the first place was 341 sats short.
  ///
  /// Verified against mempool.space on 2026-08-10: testnet3 and testnet4 both
  /// report 1 sat/vB across every tier, `fastestFee` included, so there is no
  /// backlog to outbid. 10 leaves a wide margin anyway, because testnet3 mines
  /// in bursts — the 20-minute difficulty reset makes block intervals erratic —
  /// and a transaction left unconfirmed between runs is what would corrupt the
  /// next run's UTXO set. Ten times the fastest recommendation buys that safety
  /// for a few hundred sats.
  const testnetFeeRate = 10.0;

  Future<void> consolidateUtxos(Wallet wallet) async {
    final utxos = requireValue(wallet.coins.now.latest, 'read fixture coins');
    if (utxos.length <= 1) return;
    final walletId = wallet.key.id;
    final address = requireValue(
      await addresses.receiveAddress(walletId: walletId, advance: true),
      'issue a consolidation address',
    );
    final prepared = requireValue(
      await spend.prepareBitcoin(
        walletId: walletId,
        recipients: [
          BitcoinTransactionRecipient.remainder(address: address.address),
        ],
        networkFee: NetworkFee.relativeFromSatPerVbyte(testnetFeeRate),
      ),
      'prepare the consolidation',
    );
    final signed = requireValue(
      await spend.signBitcoin(prepared: prepared),
      'sign the consolidation',
    );
    requireValue(
      await spend.broadcastBitcoin(signed),
      'broadcast the consolidation',
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    await syncFundedTestnetWallet(wallet.key);
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
      senderMnemonic.isNotEmpty &&
      Platform.environment['RUN_FUNDED_PAYJOIN_TEST'] == 'true';
  const fixtureSkip =
      'requires a PR to main or a manually dispatched CI run with funded testnet wallets';

  // Belongs to this file's own Bull.init above, not to the fixtures, so it
  // stays at the root scope and runs even when the funded group is skipped.
  // all_test.dart owns the lifecycle when it calls main(isInitialized: true).
  tearDownAll(() async {
    if (isInitialized) return;
    if (locator.isRegistered<PayjoinLifecycle>()) {
      await locator<PayjoinLifecycle>().dispose();
    }
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

  // The skip has to sit on the group, not on each test: a group whose tests
  // are individually skipped still runs its setUpAll and tearDownAll, whereas
  // a skipped group runs neither. Verified against package:test 1.31.
  //
  // This also keeps shared funded wallets out of concurrent pull-request jobs.
  // Every such job otherwise derives the same BIP84 account and broadcasts
  // consolidation transactions from the same UTXOs, causing RBF conflicts.
  // The workflow enables this group for delivery PRs to main or manual runs,
  // not for every branch in a concurrent develop stack.
  //
  // Scoping the hooks to the group also stops them leaking into the other
  // seven aggregated files, which previously inherited this setUp and paid a
  // full wallet sync before every one of their tests.
  group('funded testnet Payjoin', () {
    setUpAll(() async {
      addresses = locator<AddressView>();
      receiverRole = locator<PayjoinReceiver>();
      senderRole = locator<PayjoinSender>();
      sessions = locator<PayjoinSessions>();
      policy = locator<PayjoinPolicyAccess>();
      spend = locator<Spend>();

      // Testnet is a developer network: enable it as a user would.
      // Restored when the group ends, even if this setup fails.
      await selectDeveloperNetwork(Environment.testnet);
      final currentPolicy = await policy.load();
      previousPayjoinPolicy = switch (currentPolicy) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
      // A payjoin between two user wallets needs both user switches.
      for (final action in [PayjoinAction.send, PayjoinAction.receive]) {
        final enabled = await policy.setActionEnabled(action, enabled: true);
        if (enabled case Err(:final failure)) throw failure;
      }

      Future<WalletKey> openWallet(String mnemonic) => openFundedTestnetWallet(
        mnemonic: mnemonic,
        secrets: locator<Secrets>(),
        inventory: locator<SecretsInventory>(),
        native: locator<WalletNativeRuntime>(),
      );

      receiverKey = await openWallet(
        receiverMnemonic ?? fail('missing Alice fixture'),
      );
      senderKey = await openWallet(
        senderMnemonic ?? fail('missing Bob fixture'),
      );
      expect(
        senderKey.id,
        isNot(receiverKey.id),
        reason:
            'The funded Payjoin requires distinct sender and receiver accounts',
      );
    });

    // The network and developer flags are restored by selectDeveloperNetwork,
    // independently of this policy restore.
    tearDownAll(() async {
      if (previousPayjoinPolicy case final previous?) {
        for (final action in [PayjoinAction.send, PayjoinAction.receive]) {
          final restored = await policy.setActionEnabled(
            action,
            enabled: previous.allows(action),
          );
          if (restored case Err(:final failure)) throw failure;
        }
      }
    });

    setUp(() async {
      receiverWallet = await syncFundedTestnetWallet(receiverKey);
      senderWallet = await syncFundedTestnetWallet(senderKey);
    });

    test('funded testnet wallets complete a Payjoin', () async {
      final receiverBalance = requireValue(
        receiverWallet.balances.now.latest,
        'read the receiver balance',
      );
      final senderBalance = requireValue(
        senderWallet.balances.now.latest,
        'read the sender balance',
      );
      expect(receiverBalance.totalSat, greaterThan(BigInt.zero));
      expect(senderBalance.totalSat, greaterThan(BigInt.zero));

      await consolidateUtxos(receiverWallet);
      await consolidateUtxos(senderWallet);

      final addressResult = await addresses.receiveAddress(
        walletId: receiverKey.id,
        advance: true,
      );
      final address = switch (addressResult) {
        Ok(:final value) => value,
        Err(:final failure) => fail(failure.runtimeType.toString()),
      };
      final receiverResult = await receiverRole.start(
        StartPayjoinReceiver(
          walletId: receiverKey.id,
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

      const feeRate = testnetFeeRate;
      final preparationResult = await spend.prepareBitcoin(
        walletId: senderKey.id,
        recipients: [
          BitcoinTransactionRecipient.fixed(
            address: address.address,
            amountSat: Sats.fromInt(10000),
          ),
        ],
        networkFee: NetworkFee.relativeFromSatPerVbyte(feeRate),
      );
      final prepared = switch (preparationResult) {
        Ok(:final value) => value,
        Err(:final failure) => fail(
          'Bitcoin preparation failed: ${failure.runtimeType}',
        ),
      };
      final original = requireValue(
        await preparePayjoinOriginal(
          spend: spend,
          prepared: prepared,
          walletId: senderKey.id,
          network: BitcoinNetwork.testnet,
        ),
        'prepare the guarded Payjoin original',
      );
      final senderResult = await senderRole.start(
        StartPayjoinSender(
          walletId: senderKey.id,
          network: BitcoinNetwork.testnet,
          bip21Uri: receiver.pjUri,
          unsignedOriginalPsbt: prepared.unsignedPsbt,
          preparedOriginal: original,
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
    }, timeout: const Timeout(Duration(seconds: 330)));

    test('a receiver expires when no sender submits a request', () async {
      final addressResult = await addresses.receiveAddress(
        walletId: receiverKey.id,
        advance: true,
      );
      final address = switch (addressResult) {
        Ok(:final value) => value,
        Err(:final failure) => fail(failure.runtimeType.toString()),
      };
      final receiverResult = await receiverRole.start(
        StartPayjoinReceiver(
          walletId: receiverKey.id,
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
    }, timeout: const Timeout(Duration(seconds: 270)));
  }, skip: hasFixtures ? null : fixtureSkip);
}
