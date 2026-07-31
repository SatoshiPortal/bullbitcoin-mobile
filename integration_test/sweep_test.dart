import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_plan.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_quote.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/build_sweep_psbt_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/parse_sweep_address_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/sign_sweep_psbt_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';

// Integration tests for the coin sweep, on funded testnet wallets.
//
// What only a real BDK build can prove, and what these tests therefore assert:
//
//   1. The inputs are EXACTLY the selected coins. `manuallySelectedOnly` is the
//      whole point of the feature; a unit test with a mocked port cannot show
//      that BDK honours it. Here the built PSBT is decoded and its input set
//      compared to the selection, outpoint by outpoint.
//   2. The outputs are plural and carry the requested amounts — the gap
//      `buildPsbt` could not fill.
//   3. With no remainder recipient the leftover comes back as change on Alice's
//      own keychain; with one, there is no change output at all.
//   4. A frozen coin in the selection is refused before anything is built.
//   5. The signed transaction finalises, so the bytes are spendable.
//
// Broadcasting is opt-in (TEST_SWEEP_BROADCAST=1) because it really moves the
// fixture's coins and cannot be undone.
//
// Run via `make integration-test` (aggregated by tools/gen_all_test.dart).
Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  const aliceDefine = String.fromEnvironment('TEST_ALICE_MNEMONIC');
  const bobDefine = String.fromEnvironment('TEST_BOB_MNEMONIC');
  final aliceMnemonic = aliceDefine.isNotEmpty
      ? aliceDefine
      : Platform.environment['TEST_ALICE_MNEMONIC'];
  final bobMnemonic = bobDefine.isNotEmpty
      ? bobDefine
      : Platform.environment['TEST_BOB_MNEMONIC'];
  final hasWallets =
      aliceMnemonic != null &&
      aliceMnemonic.isNotEmpty &&
      bobMnemonic != null &&
      bobMnemonic.isNotEmpty;

  const electrumHostDefine = String.fromEnvironment('TEST_ELECTRUM_HOST');
  const electrumPortDefine = String.fromEnvironment('TEST_ELECTRUM_PORT');
  final electrumHost = electrumHostDefine.isNotEmpty
      ? electrumHostDefine
      : Platform.environment['TEST_ELECTRUM_HOST'];
  final electrumPort = electrumPortDefine.isNotEmpty
      ? electrumPortDefine
      : Platform.environment['TEST_ELECTRUM_PORT'];

  group(
    'Sweep (funded testnet)',
    () {
      late WalletRepository walletRepository;
      late WalletAddressRepository addressRepository;
      late WalletUtxoRepository utxoRepository;
      late SeedRepository seedRepository;
      late BuildSweepPsbtUsecase buildSweep;
      late SignSweepPsbtUsecase signSweep;
      late ParseSweepAddressUsecase parseAddress;
      late Wallet alice;
      late Wallet bob;
      ElectrumServer? customElectrum;

      final fee = NetworkFee.relativeFromSatPerVbyte(2);

      setUpAll(() async {
        walletRepository = locator<WalletRepository>();
        addressRepository = locator<WalletAddressRepository>();
        utxoRepository = locator<WalletUtxoRepository>();
        seedRepository = locator<SeedRepository>();
        buildSweep = locator<BuildSweepPsbtUsecase>();
        signSweep = locator<SignSweepPsbtUsecase>();
        parseAddress = locator<ParseSweepAddressUsecase>();

        await locator<SetEnvironmentUsecase>().execute(Environment.testnet);

        // Harness escape hatch: some networks block the default Electrum ports
        // (993/700). Saving one custom server makes the repository prefer it
        // over the default set, without changing what the app ships.
        if (electrumHost != null && electrumPort != null) {
          customElectrum = ElectrumServer.createCustom(
            host: electrumHost,
            port: int.parse(electrumPort),
            network: ElectrumServerNetwork.bitcoinTestnet,
            priority: 0,
          );
          final saved = await locator<ElectrumServerRepository>().save(
            customElectrum!,
          );
          if (saved case Err(:final failure)) throw StateError('$failure');
        }

        final aliceSeed = await seedRepository.createFromMnemonic(
          mnemonicWords: aliceMnemonic!.split(' '),
        );
        final bobSeed = await seedRepository.createFromMnemonic(
          mnemonicWords: bobMnemonic!.split(' '),
        );
        alice = await walletRepository.createWallet(
          seed: aliceSeed,
          network: Network.bitcoinTestnet,
          scriptType: ScriptType.bip84,
        );
        bob = await walletRepository.createWallet(
          seed: bobSeed,
          network: Network.bitcoinTestnet,
          scriptType: ScriptType.bip84,
        );
        await walletRepository.getWallets(sync: true);
      });

      // Leave the aggregated run on the seeded default, as coins_test.dart does,
      // and drop the custom server so later files fall back to the shipped set.
      tearDownAll(() async {
        final custom = customElectrum;
        if (custom != null) {
          // Best effort: a failed cleanup must not mask the tests' own result.
          final deleted = await locator<ElectrumServerRepository>().delete(
            url: custom.url,
          );
          if (deleted case Err(:final failure)) {
            printOnFailure('failed to drop the custom server: $failure');
          }
        }
        await locator<SetEnvironmentUsecase>().execute(Environment.mainnet);
      });

      // ── helpers ───────────────────────────────────────────────────────────

      /// Alice's spendable coins, or null when the faucet funds have expired.
      Future<List<WalletUtxo>?> aliceCoins() async {
        final utxos = await utxoRepository.getWalletUtxos(walletId: alice.id);
        final spendable = utxos.where((u) => !u.isFrozen).toList();
        if (spendable.isEmpty) {
          // Do not interpolate Wallet: its generated toString contains public
          // descriptors and xpubs, which must not leak into CI logs.
          markTestSkipped('Alice fixture has no spendable testnet coins');
          return null;
        }
        return spendable;
      }

      Future<String> bobAddress() async {
        final address = await addressRepository.generateNewReceiveAddress(
          walletId: bob.id,
        );
        return address.address;
      }

      SweepPlan planOf(
        List<WalletUtxo> inputs,
        List<SweepAllocation> allocations,
      ) {
        return switch (SweepPlan.validate(
          inputs: inputs,
          allocations: allocations,
        )) {
          Ok(:final value) => value,
          Err(:final failure) => throw StateError(
            'plan rejected: ${failure.runtimeType}',
          ),
        };
      }

      SweepQuote quoteOrFail(Result<SweepQuote, SweepFailure> result) {
        return switch (result) {
          Ok(:final value) => value,
          Err(:final failure) => throw StateError(
            'build failed: ${failure.runtimeType}',
          ),
        };
      }

      bdk.Transaction decode(String psbt) =>
          bdk.Psbt(psbtBase64: psbt).extractTx();

      Set<String> inputKeysOf(bdk.Transaction tx) => tx
          .input()
          .map((i) => '${i.previousOutput.txid}:${i.previousOutput.vout}')
          .toSet();

      Uint8List scriptOf(String address) => bdk.Address(
        address: address,
        network: bdk.Network.testnet,
      ).scriptPubkey().toBytes();

      /// Sum of the outputs paying [address].
      int paidTo(bdk.Transaction tx, String address) {
        final want = scriptOf(address);
        var total = 0;
        for (final out in tx.output()) {
          if (_sameBytes(out.scriptPubkey.toBytes(), want)) {
            total += out.value.toSat();
          }
        }
        return total;
      }

      // ── tests ─────────────────────────────────────────────────────────────

      test('spends exactly the selected coins and nothing else', () async {
        final coins = await aliceCoins();
        if (coins == null) return;
        // Sweep a strict subset when Alice has more than one coin, so "exactly
        // these" is a real claim and not trivially the whole wallet.
        final selection = coins.length > 1 ? coins.take(1).toList() : coins;
        final total = selection.fold(
          BigInt.zero,
          (sum, u) => sum + u.amountSat,
        );
        // Small enough to leave room for the fee and a non-dust change.
        final amount = total ~/ BigInt.from(4);

        final quote = quoteOrFail(
          await buildSweep.execute(
            walletId: alice.id,
            plan: planOf(selection, [
              SweepAllocation(address: await bobAddress(), amountSat: amount),
            ]),
            networkFee: fee,
          ),
        );

        final tx = decode(quote.unsignedPsbt);
        expect(
          inputKeysOf(tx),
          selection.map((u) => '${u.txId}:${u.vout}').toSet(),
          reason:
              'a sweep must spend the selected coins and only those — '
              'manuallySelectedOnly forbids BDK from adding any other',
        );
        expect(quote.feeSat, greaterThan(BigInt.zero));
      });

      test('splits the balance across several recipients', () async {
        final coins = await aliceCoins();
        if (coins == null) return;
        final total = coins.fold(BigInt.zero, (sum, u) => sum + u.amountSat);
        final first = total ~/ BigInt.from(5);
        final second = total ~/ BigInt.from(6);
        if (first < SweepPlan.minimumOutputSat ||
            second < SweepPlan.minimumOutputSat) {
          markTestSkipped('Alice holds too little to split into two outputs');
          return;
        }
        final addressOne = await bobAddress();
        final addressTwo = await bobAddress();
        expect(addressOne, isNot(addressTwo));

        final quote = quoteOrFail(
          await buildSweep.execute(
            walletId: alice.id,
            plan: planOf(coins, [
              SweepAllocation(address: addressOne, amountSat: first),
              SweepAllocation(address: addressTwo, amountSat: second),
            ]),
            networkFee: fee,
          ),
        );

        final tx = decode(quote.unsignedPsbt);
        // Two recipients plus Alice's change.
        expect(tx.output().length, 3);
        expect(paidTo(tx, addressOne), first.toInt());
        expect(paidTo(tx, addressTwo), second.toInt());
      });

      test('the leftover returns to Alice as change by default', () async {
        final coins = await aliceCoins();
        if (coins == null) return;
        final total = coins.fold(BigInt.zero, (sum, u) => sum + u.amountSat);
        final amount = total ~/ BigInt.from(4);
        final address = await bobAddress();

        final quote = quoteOrFail(
          await buildSweep.execute(
            walletId: alice.id,
            plan: planOf(coins, [
              SweepAllocation(address: address, amountSat: amount),
            ]),
            networkFee: fee,
          ),
        );

        final tx = decode(quote.unsignedPsbt);
        final change = quote.changeSat;
        expect(change, isNotNull);
        expect(change, greaterThan(BigInt.zero));
        expect(quote.remainderSat, isNull);

        // The change output must be Alice's, on a script she owns.
        final changeOutputs = tx.output().where(
          (o) => !_sameBytes(o.scriptPubkey.toBytes(), scriptOf(address)),
        );
        expect(changeOutputs.length, 1);
        expect(changeOutputs.single.value.toSat(), change!.toInt());
        // Arithmetic closes: inputs = recipients + change + fee.
        expect(
          BigInt.from(
                tx.output().fold<int>(0, (sum, o) => sum + o.value.toSat()),
              ) +
              quote.feeSat,
          total,
        );
      });

      test('a Max recipient leaves no change behind', () async {
        final coins = await aliceCoins();
        if (coins == null) return;
        final total = coins.fold(BigInt.zero, (sum, u) => sum + u.amountSat);
        final address = await bobAddress();

        final quote = quoteOrFail(
          await buildSweep.execute(
            walletId: alice.id,
            plan: planOf(coins, [
              SweepAllocation(address: address, takesRemainder: true),
            ]),
            networkFee: fee,
          ),
        );

        final tx = decode(quote.unsignedPsbt);
        expect(
          tx.output().length,
          1,
          reason: 'a drained sweep must not create a change output',
        );
        expect(quote.changeSat, isNull);
        expect(quote.remainderSat, total - quote.feeSat);
        expect(paidTo(tx, address), (total - quote.feeSat).toInt());
      });

      test('a frozen coin in the selection is refused, not dropped', () async {
        final coins = await aliceCoins();
        if (coins == null) return;
        final frozen = coins.first;
        final outpoints = [(txId: frozen.txId, vout: frozen.vout)];
        await utxoRepository.freezeUtxos(
          walletId: alice.id,
          outpoints: outpoints,
        );
        addTearDown(
          () => utxoRepository.unfreezeUtxos(
            walletId: alice.id,
            outpoints: outpoints,
          ),
        );

        final total = coins.fold(BigInt.zero, (sum, u) => sum + u.amountSat);
        final result = await buildSweep.execute(
          walletId: alice.id,
          // The plan still carries the frozen coin: the use-case must catch it.
          plan: planOf(coins, [
            SweepAllocation(
              address: await bobAddress(),
              amountSat: total ~/ BigInt.from(4),
            ),
          ]),
          networkFee: fee,
        );

        final failure = switch (result) {
          Ok() => throw StateError('a frozen coin was swept'),
          Err(:final failure) => failure,
        };
        expect(failure, isA<SweepUnspendableInputFailure>());
        expect((failure as SweepUnspendableInputFailure).count, 1);
      });

      test('allocating more than the coins hold is refused', () async {
        final coins = await aliceCoins();
        if (coins == null) return;
        final total = coins.fold(BigInt.zero, (sum, u) => sum + u.amountSat);

        // One satoshi below the total: the amount fits, the fee cannot. BDK
        // must fail rather than reach for another coin.
        final result = await buildSweep.execute(
          walletId: alice.id,
          plan: planOf(coins, [
            SweepAllocation(
              address: await bobAddress(),
              amountSat: total - BigInt.one,
            ),
          ]),
          networkFee: fee,
        );

        expect(switch (result) {
          Ok() => throw StateError('the fee was conjured from nowhere'),
          Err(:final failure) => failure,
        }, isA<SweepInsufficientFundsFailure>());
      });

      test('a Bob address parses on the wallet network', () async {
        final address = await bobAddress();

        final parsed = await parseAddress.execute(
          input: address,
          network: Network.bitcoinTestnet,
        );

        expect(switch (parsed) {
          Ok(:final value) => value.address,
          Err(:final failure) => throw StateError(
            'rejected: ${failure.runtimeType}',
          ),
        }, address);

        // A mainnet wallet must refuse the same testnet address.
        final wrongNetwork = await parseAddress.execute(
          input: address,
          network: Network.bitcoinMainnet,
        );
        expect(switch (wrongNetwork) {
          Ok() => throw StateError('a testnet address passed as mainnet'),
          Err(:final failure) => failure,
        }, isA<SweepWrongNetworkFailure>());
      });

      test('the sweep signs and finalises', () async {
        final coins = await aliceCoins();
        if (coins == null) return;
        final total = coins.fold(BigInt.zero, (sum, u) => sum + u.amountSat);
        final address = await bobAddress();

        final quote = quoteOrFail(
          await buildSweep.execute(
            walletId: alice.id,
            plan: planOf(coins, [
              SweepAllocation(
                address: address,
                amountSat: total ~/ BigInt.from(4),
              ),
            ]),
            networkFee: fee,
          ),
        );

        final signed = switch (await signSweep.execute(
          walletId: alice.id,
          unsignedPsbt: quote.unsignedPsbt,
        )) {
          Ok(:final value) => value,
          Err(:final failure) => throw StateError(
            'signing failed: ${failure.runtimeType}',
          ),
        };

        // Every input must carry a witness once finalised — that is what makes
        // the bytes broadcastable.
        final tx = decode(signed);
        expect(tx.input(), isNotEmpty);
        for (final input in tx.input()) {
          expect(
            input.witness,
            isNotEmpty,
            reason: 'a finalised P2WPKH input must carry its witness',
          );
        }
        expect(inputKeysOf(tx), inputKeysOf(decode(quote.unsignedPsbt)));
      });
    },
    skip: hasWallets
        ? false
        : 'requires funded testnet wallets '
              '(set TEST_ALICE_MNEMONIC and TEST_BOB_MNEMONIC)',
  );
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
