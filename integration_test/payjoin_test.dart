import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:address_view/address_view.dart';
import 'package:bb_mobile/init.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/payjoin.dart';
import 'package:spend/spend.dart';
import 'package:sync/sync.dart';

import 'funded_regtest_wallet.dart';
import 'initialization_result.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) {
    requireSuccessfulBullInitialization(
      await Bull.init(
        initialNetwork: localRegtest ? Environment.regtest : null,
      ),
    );
  }

  late final AddressView addresses;
  late final PayjoinReceiver receiverRole;
  late final PayjoinSender senderRole;
  late final PayjoinSessions sessions;
  late final PayjoinPolicyAccess policy;
  late final Spend spend;

  late WalletKey receiverKey;
  late Wallet receiverWallet;
  PayjoinPolicy? previousPayjoinPolicy;

  Future<(Process, Directory)> startPeer(List<String> arguments) async {
    final peer = Platform.environment['BULL_PAYJOIN_TEST_PEER'];
    final certificate = Platform.environment['BULL_PAYJOIN_TEST_CERT'];
    if (peer == null || certificate == null) {
      throw StateError('The isolated Payjoin peer is not configured');
    }
    final directory = await Directory.systemTemp.createTemp('payjoin-peer-');
    try {
      final process = await Process.start(peer, [
        '--rpchost',
        'http://127.0.0.1:18443/wallet/ci',
        '--rpcuser',
        'ci',
        '--rpcpassword',
        'ci',
        '--ohttp-relays',
        'https://127.0.0.1:8041',
        '--pj-directories',
        'https://localhost:8040',
        '--root-certificate',
        certificate,
        ...arguments,
      ], workingDirectory: directory.path);
      return (process, directory);
    } on Exception {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

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
    skip: 'Requires a fixture that coordinates concurrent sessions',
  );

  group('local regtest Payjoin', () {
    setUpAll(() async {
      addresses = locator<AddressView>();
      receiverRole = locator<PayjoinReceiver>();
      senderRole = locator<PayjoinSender>();
      sessions = locator<PayjoinSessions>();
      policy = locator<PayjoinPolicyAccess>();
      spend = locator<Spend>();

      final settings = requireValue(
        await locator<Preferences>().fetch(),
        'read startup environment',
      );
      expect(settings.environment, Environment.regtest);
      expect(settings.activeNetwork, NetworkEnv.regtest);
      final currentPolicy = await policy.load();
      previousPayjoinPolicy = switch (currentPolicy) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
      for (final action in [PayjoinAction.send, PayjoinAction.receive]) {
        final enabled = await policy.setActionEnabled(action, enabled: true);
        if (enabled case Err(:final failure)) throw failure;
      }

      receiverWallet = await fundedRegtestWallet();
      receiverKey = receiverWallet.key;
    });

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

    test('funded regtest wallets complete a Payjoin', () async {
      final receiverBalance = requireValue(
        receiverWallet.balances.now.latest,
        'read the receiver balance',
      );
      expect(receiverBalance.totalSat, greaterThan(BigInt.zero));

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
          network: BitcoinNetwork.regtest,
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

      final (process, directory) = await startPeer([
        'send',
        '--fee-rate',
        '10',
        receiver.pjUri,
      ]);
      final stdoutDone = process.stdout.drain<void>();
      final stderrDone = process.stderr.drain<void>();
      try {
        final exitCode = await process.exitCode.timeout(
          const Duration(seconds: 120),
        );
        expect(exitCode, 0, reason: 'The isolated Payjoin peer failed');
      } finally {
        process.kill();
        await stdoutDone;
        await stderrDone;
        await directory.delete(recursive: true);
      }

      final completed = await sessions
          .watch(sessionIds: {receiver.id})
          .where(
            (result) => switch (result) {
              Ok(:final value) =>
                value.status == PayjoinStatus.completed ||
                    value.status == PayjoinStatus.aborted ||
                    value.status == PayjoinStatus.expired,
              Err() => true,
            },
          )
          .first
          .timeout(const Duration(seconds: 300));
      expect(completed, isA<Ok<PayjoinSession, PayjoinFailure>>());
      final session = requireValue(completed, 'read the final Payjoin state');
      expect(session.status, PayjoinStatus.completed);
    }, timeout: const Timeout(Duration(seconds: 330)));

    test(
      'a regtest sender completes a Payjoin with an independent receiver',
      () async {
        final wallet = await fundedRegtestWallet();
        final (process, directory) = await startPeer(['receive', '10000']);
        final uriReady = Completer<String>();
        final output = process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (line.startsWith('bitcoin:') && !uriReady.isCompleted) {
                  uriReady.complete(line);
                }
              },
              onDone: () {
                if (!uriReady.isCompleted) {
                  uriReady.completeError(
                    StateError('Peer did not issue a URI'),
                  );
                }
              },
            );
        final stderrDone = process.stderr.drain<void>();
        try {
          final bip21 = await uriReady.future.timeout(
            const Duration(seconds: 60),
          );
          final uri = Uri.parse(bip21);
          expect(uri.scheme, 'bitcoin');
          expect(uri.queryParameters, contains('pj'));
          final prepared = requireValue(
            await spend.prepareBitcoin(
              walletId: wallet.key.id,
              recipients: [
                BitcoinTransactionRecipient.fixed(
                  address: uri.path,
                  amountSat: Sats.fromInt(10000),
                ),
              ],
              networkFee: NetworkFee.relativeFromSatPerVbyte(10),
            ),
            'prepare the sender transaction',
          );
          final original = requireValue(
            await preparePayjoinOriginal(
              spend: spend,
              prepared: prepared,
              walletId: wallet.key.id,
              network: BitcoinNetwork.regtest,
            ),
            'prepare the guarded Payjoin original',
          );
          final sender = requireValue(
            await senderRole.start(
              StartPayjoinSender(
                walletId: wallet.key.id,
                network: BitcoinNetwork.regtest,
                bip21Uri: bip21,
                unsignedOriginalPsbt: prepared.unsignedPsbt,
                preparedOriginal: original,
                amount: Sats.fromInt(10000),
                feeRate: FeeRate(10),
              ),
            ),
            'start the Payjoin sender',
          );
          final terminal = await sessions
              .watch(sessionIds: {sender.id})
              .where(
                (result) => switch (result) {
                  Ok(:final value) =>
                    value.status == PayjoinStatus.completed ||
                        value.status == PayjoinStatus.aborted ||
                        value.status == PayjoinStatus.expired,
                  Err() => true,
                },
              )
              .first
              .timeout(const Duration(seconds: 120));
          expect(
            requireValue(terminal, 'read the final sender state').status,
            PayjoinStatus.completed,
          );
        } finally {
          process.kill();
          await process.exitCode;
          await output.cancel();
          await stderrDone;
          await directory.delete(recursive: true);
        }
      },
      timeout: const Timeout(Duration(seconds: 210)),
    );

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
          network: BitcoinNetwork.regtest,
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
              Err() => true,
            },
          )
          .first
          .timeout(const Duration(seconds: 240));

      expect(
        requireValue(expired, 'read the final receiver state').status,
        PayjoinStatus.expired,
      );
    }, timeout: const Timeout(Duration(seconds: 270)));
  }, skip: localRegtest ? null : 'requires the isolated regtest runner');
}
