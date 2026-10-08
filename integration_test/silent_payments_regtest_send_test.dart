import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_sp_payment_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/send_sp_payment_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_sp_amount_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_sp_recipient_for_send_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_dev_mode_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_superuser_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/usecases/create_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/generate_taproot_address_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/scan_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/set_sp_auto_scan_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notifications_usecase.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' hide Network, ScriptType;
import 'package:secrets/secrets.dart';

/// Sends silent payments end to end on a local regtest stack, through the
/// app's own layers: the default wallets are created from fixed words, the SP
/// wallet is set up on regtest with the custom backend URLs, and both sends go
/// through the send feature's use cases into the SP repository: the watch-only
/// account prepares the unsigned PSBT, the custody package signs it through
/// bwk's stateless signer, the same account finalizes it (BIP375 verification
/// and the simulation pin), and the repository checks the extracted
/// transaction against its simulation before broadcasting.
///
/// Needs a bitcoind (RPC, wallet `miner` funded), an electrs and a
/// blindbit-oracle reachable from the device, so it skips itself unless run
/// with `--dart-define=SP_REGTEST=1`. The other defines default to the ports
/// `adb reverse` publishes on the device's localhost:
///
/// ```sh
/// adb reverse tcp:8000 tcp:8000; adb reverse tcp:50001 tcp:50001
/// adb reverse tcp:18443 tcp:18443
/// fvm flutter test integration_test/silent_payments_regtest_send_test.dart \
///   --dart-define=SP_REGTEST=1 --dart-define=SP_RPC_COOKIE="$(cat .cookie)"
/// ```
///
/// Expects a fresh install: default wallets that exist already must be the
/// ones the fixed words below create.
Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  const enabled = String.fromEnvironment('SP_REGTEST') == '1';
  const blindbitUrl = String.fromEnvironment(
    'SP_BLINDBIT_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  // bwk reads a plain host:port or a tcp:// URL as plain TCP.
  const electrumUrl = String.fromEnvironment(
    'SP_ELECTRUM_URL',
    defaultValue: 'tcp://127.0.0.1:50001',
  );
  const rpcUrl = String.fromEnvironment(
    'SP_RPC_URL',
    defaultValue: 'http://127.0.0.1:18443',
  );
  // `user:password` from bitcoind's .cookie file.
  const rpcCookie = String.fromEnvironment('SP_RPC_COOKIE');

  if (enabled && !isInitialized) await Bull.init();

  // The published BIP39 vector for zero entropy. Public, regtest only.
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];

  const fundingSat = 100000000;
  const selfSendSat = 40000000;
  // More than either coin the self-send leaves, so the external send has to
  // spend both silent payment outputs, the change among them.
  const externalSendSat = 70000000;
  final fee = NetworkFee.relativeFromSatPerVbyte(2);

  final rpc = _BitcoindRpc(Uri.parse(rpcUrl), rpcCookie);

  // Every line the app logs, so the test can tell that the signed-vs-simulated
  // check passed rather than infer it.
  final logLines = <String>[];
  DebugPrintCallback? previousDebugPrint;

  group(
    'silent payments on regtest',
    () {
      setUpAll(() async {
        expect(rpcCookie, isNotEmpty, reason: 'pass SP_RPC_COOKIE');
        previousDebugPrint = debugPrint;
        final print = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) logLines.add(message);
          print(message, wrapWidth: wrapWidth);
        };

        // Setup: assert rather than discard, so a failed write surfaces here
        // instead of as a confusing failure further down the test.
        expect(
          await locator<SetEnvironmentUsecase>().execute(Environment.testnet),
          isA<Ok<void, SettingsFailure>>(),
        );
        expect(
          await locator<SetIsSuperuserUsecase>().execute(true),
          isA<Ok<void, SettingsFailure>>(),
        );
        expect(
          await locator<SetIsDevModeUsecase>().execute(true),
          isA<Ok<void, SettingsFailure>>(),
        );
        // The sync tick would otherwise resume scans of its own, and a second
        // scan is refused while one runs.
        await locator<SetSpAutoScanUsecase>().execute(isEnabled: false);

        final secrets = locator<Secrets>();
        final fingerprint = switch (await secrets.import(words: words)) {
          Ok(:final value) => value.info.id,
          Err(failure: SecretAlreadyExistsFailure(:final id)) => id,
          Err(:final failure) => fail('import: ${failure.runtimeType}'),
        };
        final existing = switch (await locator<WalletRepository>().getWallets(
          environment: Environment.testnet,
          onlyDefaults: true,
          onlyBitcoin: true,
        )) {
          Ok(:final value) => value,
          Err(:final failure) => fail('wallets: ${failure.runtimeType}'),
        };
        if (existing.isEmpty) {
          await locator<CreateDefaultWalletsUsecase>().execute(
            mnemonicWords: words,
          );
        } else {
          expect(
            existing.first.masterFingerprint,
            fingerprint.hex,
            reason: 'run on a fresh install: other default wallets exist',
          );
        }
      });

      tearDownAll(() async {
        if (previousDebugPrint case final print?) debugPrint = print;
        expect(
          await locator<SetEnvironmentUsecase>().execute(Environment.mainnet),
          isA<Ok<void, SettingsFailure>>(),
        );
      });

      test(
        'receives, self-sends and spends silent payment outputs',
        () async {
          final spFacade = locator<SpFacade>();
          final scan = locator<ScanSpWalletUsecase>();
          final loadData = locator<LoadSpWalletDataUsecase>();
          final notifications = locator<WatchSpNotificationsUsecase>();

          // 1. The SP wallet, as the setup screen creates it.
          final created = await locator<CreateSpWalletUsecase>().execute(
            network: BitcoinNetwork.regtest,
            blindbitUrl: blindbitUrl,
            electrumUrl: electrumUrl,
            scanFromNow: false,
          );
          expect(created, isA<Ok<void, SpFailure>>(), reason: '$created');
          expect(spFacade.network(), isA<Ok<BitcoinNetwork?, SpFailure>>());
          expect(
            (spFacade.network() as Ok<BitcoinNetwork?, SpFailure>).value,
            BitcoinNetwork.regtest,
          );

          final spAddress = _ok(await spFacade.refresh())!.spAddress;
          expect(spAddress, startsWith('sprt1'));
          debugPrint('SP-E2E sp address $spAddress');

          Future<SpBalance> balance() async =>
              _ok(await spFacade.refresh())!.balance;

          Future<List<SpCoin>> coins() async =>
              _ok(await loadData.execute()).coins;

          Future<void> waitFor(
            String what,
            Future<bool> Function() condition,
          ) async {
            final deadline = DateTime.now().add(const Duration(seconds: 120));
            while (!await condition()) {
              if (DateTime.now().isAfter(deadline)) fail('timed out: $what');
              await Future<void>.delayed(const Duration(seconds: 1));
            }
          }

          Future<int> mineOne() async {
            final address = await rpc.call('getnewaddress', wallet: 'miner');
            await rpc.call('generatetoaddress', params: [1, address]);
            final height = await rpc.call('getblockcount') as int;
            await waitFor('blindbit at $height', () async {
              final body = await _get(Uri.parse('$blindbitUrl/block-height'));
              return (jsonDecode(body)['block_height'] as int) >= height;
            });
            return height;
          }

          Future<void> scanOnce({int? startHeight}) async {
            final outcome = notifications
                .execute()
                .firstWhere(
                  (n) =>
                      n is SpScanCompleted ||
                      n is SpScanFailed ||
                      n is SpScanStopped,
                )
                .timeout(const Duration(seconds: 180));
            // The stream is an async generator, so it reaches the session's
            // stream a few microtasks after listen.
            await Future<void>.delayed(const Duration(milliseconds: 200));
            final started = await scan.execute(startHeight: startHeight);
            expect(started, isA<Ok<void, SpFailure>>(), reason: '$started');
            final result = await outcome;
            expect(result, isA<SpScanCompleted>(), reason: '$result');
          }

          // Sends exactly as the send screen does: validate the recipient and
          // the amount, simulate for the confirm page, then send that draft.
          Future<(SpTxDraft, String)> send(String recipient, int amount) async {
            final validated = await locator<ValidateSpRecipientForSendUsecase>()
                .execute(
                  input: recipient,
                  amountSat: Sats.fromInt(amount),
                  isMax: false,
                );
            final spRecipient = _ok(validated);
            final amountOk = locator<ValidateSpAmountForSendUsecase>().execute(
              Sats.fromInt(amount),
            );
            _ok(amountOk);
            final draft = _ok(
              await locator<PrepareSpPaymentForSendUsecase>().execute(
                recipients: [spRecipient],
                fee: fee,
              ),
            );
            final logStart = logLines.length;
            final sent = await locator<SendSpPaymentForSendUsecase>().execute(
              draft: draft,
            );
            final sendLog = logLines.sublist(logStart);
            expect(
              sendLog.where(
                (l) =>
                    l.contains('finalize refused the signed PSBT') ||
                    l.contains('signed transaction refused'),
              ),
              isEmpty,
            );
            final txid = _ok(sent);
            expect(
              sendLog.any((l) => l.contains('broadcast succeeded txid=')),
              isTrue,
              reason: 'the repository logs the broadcast once the check passed',
            );
            debugPrint(
              'SP-E2E sent $amount sat to $recipient: txid=$txid '
              'inputs=${[for (final c in draft.inputs) '${c.source.name}:${c.amountSat}']} '
              'fee=${draft.feeSat} change=${draft.changeSat}',
            );
            return (draft, txid);
          }

          BigInt total(Iterable<SpCoin> coins) =>
              coins.fold(BigInt.zero, (sum, c) => sum + c.amountSat.value);

          // 2. Fund the BIP86 sub-account; the electrum listener picks it up.
          final taprootAddress = _ok(
            await locator<GenerateTaprootAddressUsecase>().execute(),
          );
          final before = await balance();
          final fundingTxid = await rpc.call(
            'sendtoaddress',
            params: [taprootAddress, fundingSat / 100000000],
            wallet: 'miner',
          );
          final fundedHeight = await mineOne();
          debugPrint(
            'SP-E2E funded $taprootAddress txid=$fundingTxid '
            'height=$fundedHeight',
          );
          await waitFor('funding seen', () async {
            final b = await balance();
            return b.confirmedSat.value ==
                before.confirmedSat.value + BigInt.from(fundingSat);
          });
          final funded = await balance();

          // 3. Self-send to the wallet's own SP address, spending the taproot
          // coin: creates an SP output and the SP change.
          final (selfDraft, selfTxid) = await send(spAddress, selfSendSat);
          expect(
            selfDraft.inputs.every((c) => c.source == SpCoinSource.taproot),
            isTrue,
          );
          expect(selfDraft.changeSat.value, greaterThan(BigInt.zero));
          expect(
            total(selfDraft.inputs) -
                BigInt.from(selfSendSat) -
                selfDraft.changeSat.value,
            selfDraft.feeSat.value,
          );
          final selfHeight = await mineOne();
          await scanOnce(startHeight: fundedHeight);

          final afterSelf = await coins();
          final selfOutputs = afterSelf
              .where(
                (c) =>
                    c.outpoint.txId == selfTxid && c.source == SpCoinSource.sp,
              )
              .toList();
          expect(
            [for (final c in selfOutputs) c.amountSat.value]..sort(),
            [BigInt.from(selfSendSat), selfDraft.changeSat.value]..sort(),
            reason: 'the payment and the change are both found by the scan',
          );
          expect(
            selfOutputs.every(
              (c) => c.status == SpCoinStatus.unspent && c.height == selfHeight,
            ),
            isTrue,
          );
          await waitFor('self-send balance', () async {
            final b = await balance();
            return b.confirmedSat.value ==
                funded.confirmedSat.value - selfDraft.feeSat.value;
          });
          final selfConfirmations =
              (await rpc.call('getrawtransaction', params: [selfTxid, true])
                  as Map)['confirmations'];
          expect(selfConfirmations, greaterThanOrEqualTo(1));

          // 4. Spend the SP outputs to an external address of the node.
          final external =
              await rpc.call('getnewaddress', wallet: 'miner') as String;
          final (externalDraft, externalTxid) = await send(
            external,
            externalSendSat,
          );
          final spentOutpoints = {
            for (final c in externalDraft.inputs) c.outpoint,
          };
          expect(
            externalDraft.inputs.every((c) => c.source == SpCoinSource.sp),
            isTrue,
          );
          expect(
            spentOutpoints,
            containsAll([for (final c in selfOutputs) c.outpoint]),
            reason: 'both the SP payment and the SP change are spent',
          );
          expect(externalDraft.changeSat.value, greaterThan(BigInt.zero));
          final externalHeight = await mineOne();
          await scanOnce();

          final received =
              await rpc.call(
                    'gettransaction',
                    params: [externalTxid],
                    wallet: 'miner',
                  )
                  as Map;
          expect(received['confirmations'], greaterThanOrEqualTo(1));
          expect(received['blockheight'], externalHeight);
          final paid = (received['details'] as List).where(
            (d) => d['address'] == external && d['category'] == 'receive',
          );
          expect(paid, hasLength(1));
          expect(
            ((paid.single['amount'] as num) * 100000000).round(),
            externalSendSat,
          );
          debugPrint(
            'SP-E2E node: $externalTxid confirmations='
            '${received['confirmations']} height=${received['blockheight']}',
          );

          final afterExternal = await coins();
          final change = afterExternal.where(
            (c) =>
                c.outpoint.txId == externalTxid && c.source == SpCoinSource.sp,
          );
          expect(change, hasLength(1), reason: 'the SP change is found');
          expect(change.single.amountSat, externalDraft.changeSat);
          expect(change.single.status, SpCoinStatus.unspent);
          expect(
            afterExternal
                .where((c) => spentOutpoints.contains(c.outpoint))
                .every((c) => c.status == SpCoinStatus.spent),
            isTrue,
          );
          await waitFor('external send balance', () async {
            final b = await balance();
            return b.confirmedSat.value ==
                funded.confirmedSat.value -
                    selfDraft.feeSat.value -
                    BigInt.from(externalSendSat) -
                    externalDraft.feeSat.value;
          });
          final end = await balance();
          debugPrint(
            'SP-E2E balances: before=${before.confirmedSat} '
            'funded=${funded.confirmedSat} end=${end.confirmedSat}',
          );
        },
        timeout: const Timeout(Duration(minutes: 15)),
      );
    },
    skip: enabled ? null : 'needs a local regtest stack: SP_REGTEST=1',
  );
}

T _ok<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('unexpected failure: ${failure.logMessage}'),
};

Future<String> _get(Uri uri) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(uri)).close();
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}

class _BitcoindRpc {
  final Uri url;
  final String cookie;

  _BitcoindRpc(this.url, this.cookie);

  Future<Object?> call(
    String method, {
    List<Object?> params = const [],
    String? wallet,
  }) async {
    final client = HttpClient();
    try {
      final target = wallet == null ? url : url.resolve('/wallet/$wallet');
      final request = await client.postUrl(target);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Basic ${base64Encode(utf8.encode(cookie))}',
      );
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'jsonrpc': '1.0',
          'id': method,
          'method': method,
          'params': params,
        }),
      );
      final response = await request.close();
      final body =
          jsonDecode(await response.transform(utf8.decoder).join()) as Map;
      if (body['error'] != null) fail('$method: ${body['error']}');
      return body['result'];
    } finally {
      client.close();
    }
  }
}
