import 'dart:io';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_build_tx_exceptions.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Integration tests for the Coins / UTXO view + freeze (issue #760).
//
// Covers the §7.1 acceptance criteria:
//   1. Freeze persists across restart — freeze an outpoint, re-init the
//      locator/SqliteDatabase, the outpoint is still frozen. Funds-free: this
//      is the load-bearing persistence guarantee and runs anywhere.
//   2. A frozen coin is never spent — freeze a real wallet outpoint, have
//      PrepareBitcoinSendUsecase build a PSBT, assert the frozen outpoint is
//      absent from the PSBT inputs (the D7 guarantee). Needs a funded testnet
//      wallet (TEST_ALICE_MNEMONIC) → skipped when absent.
//   3. The list surfaces confirmed vs unconfirmed + BIP329 labels — reads the
//      wallet's real UTXOs and asserts the confirmations/labels fields the view
//      renders. Needs a funded testnet wallet → skipped when absent.
//
// Run via `make integration-test` (auto-aggregated by tools/gen_all_test.dart).
Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  final frozenDatasource = locator<FrozenWalletUtxoDatasource>();
  final utxoRepository = locator<WalletUtxoRepository>();

  group('Coins / freeze persistence (funds-free)', () {
    const walletId = 'coins-integration-test-wallet';
    const outpoint = (
      txId: '0000000000000000000000000000000000000000000000000000000000000001',
      vout: 0,
    );

    Future<void> clear() async {
      await frozenDatasource.unfreezeOutpoints(
        walletId: walletId,
        outpoints: [outpoint],
      );
    }

    setUp(clear);
    tearDown(clear);

    test('freeze is durable across a database restart', () async {
      // Use a dedicated on-disk database, fully isolated from the locator's
      // shared SqliteDatabase singleton. Closing that singleton (the previous
      // approach) killed the connection for every other test in the aggregated
      // integration run. Here: write through one handle, close it, then reopen
      // a SECOND handle on the SAME file — a fresh connection only sees
      // committed-to-disk rows, which is exactly what "survives a restart"
      // means.
      // This test deliberately opens a second SqliteDatabase on the same file
      // to simulate a restart, on top of the locator's existing singleton.
      // Drift's "multiple databases" warning targets instances SHARING a
      // QueryExecutor (a real race) — not our case: `before` and `after` use
      // separate NativeDatabase executors and never overlap. Silence the
      // debug-only false positive for the duration of this test only, so the
      // warning still guards genuine misuse in the rest of the run.
      final previousWarnFlag =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases =
            previousWarnFlag,
      );

      final dir = await Directory.systemTemp.createTemp('coins_restart');
      addTearDown(() => dir.delete(recursive: true));
      final dbFile = File('${dir.path}/restart.sqlite');

      final before = SqliteDatabase(NativeDatabase(dbFile));
      await FrozenWalletUtxoDatasource(
        db: before,
      ).freezeOutpoints(walletId: walletId, outpoints: [outpoint]);
      await before.close();

      final after = SqliteDatabase(NativeDatabase(dbFile));
      addTearDown(after.close);
      final afterRestart = await FrozenWalletUtxoDatasource(
        db: after,
      ).getFrozenOutpoints(walletId: walletId);

      expect(
        afterRestart,
        contains(outpoint),
        reason: 'a user-frozen outpoint must persist across an app restart',
      );
    });

    test('unfreeze removes the freeze row', () async {
      await utxoRepository.freezeUtxos(
        walletId: walletId,
        outpoints: [outpoint],
      );
      await utxoRepository.unfreezeUtxos(
        walletId: walletId,
        outpoints: [outpoint],
      );

      // Freeze is matched by outpoint across all wallets — the global set must
      // no longer carry it after unfreeze.
      final remaining = await utxoRepository.getAllFrozenOutpoints();
      expect(remaining, isNot(contains(outpoint)));
    });
  });

  // -------------------------------------------------------------------------
  // Funded-testnet criteria (2) and (3). These need a wallet with real UTXOs,
  // exactly like payjoin_test.dart, so they only run when TEST_ALICE_MNEMONIC
  // is provided. Without it the structure compiles and is skipped — never
  // silently omitted.
  // -------------------------------------------------------------------------
  final mnemonic = Platform.environment['TEST_ALICE_MNEMONIC'];
  final hasFunds = mnemonic != null && mnemonic.isNotEmpty;

  group(
    'Coins / freeze enforcement (funded testnet)',
    () {
      // Resolve from the locator inside setUpAll, NOT in the group body: a
      // group callback runs at test-collection time for every group — even a
      // skipped one — so resolving here crashed loading the whole aggregated
      // all_test.dart when this group is skipped (no TEST_ALICE_MNEMONIC).
      // setUpAll only runs when the group actually runs.
      late final WalletRepository walletRepository;
      late final WalletAddressRepository addressRepository;
      late final PrepareBitcoinSendUsecase prepareBitcoinSendUsecase;
      late Wallet wallet;

      setUpAll(() async {
        walletRepository = locator<WalletRepository>();
        addressRepository = locator<WalletAddressRepository>();
        prepareBitcoinSendUsecase = locator<PrepareBitcoinSendUsecase>();

        await locator<SetEnvironmentUsecase>().execute(Environment.testnet);
        final seed = SeedModel.mnemonic(
          mnemonicWords: mnemonic!.split(' '),
        ).toEntity();
        wallet = await walletRepository.createWallet(
          seed: seed,
          network: Network.bitcoinTestnet,
          scriptType: ScriptType.bip84,
        );
        await walletRepository.getWallets(sync: true);
      });

      // Restore the shared app environment so this group can't leave the
      // aggregated run on testnet — later files (e.g. sqlite_transactions)
      // fetch mainnet data through env-bound ports and would otherwise fail.
      // mainnet is the seeded default (database_seeds.dart).
      tearDownAll(
        () => locator<SetEnvironmentUsecase>().execute(Environment.mainnet),
      );

      test('list surfaces confirmations and labels per UTXO', () async {
        final utxos = await utxoRepository.getWalletUtxos(walletId: wallet.id);
        if (utxos.isEmpty) {
          // The mnemonic is set but the testnet wallet has no UTXOs (faucet
          // funds expire). Skip rather than hard-fail CI — the D7 exclusion
          // guarantee is covered deterministically by the prepare-send unit
          // tests; this group is the live, best-effort on-chain confirmation.
          markTestSkipped('testnet wallet $wallet is unfunded');
          return;
        }

        // confirmations is intrinsic per-UTXO data (D2); confirmed coins carry
        // a positive count and isConfirmed mirrors it.
        for (final utxo in utxos) {
          expect(utxo.confirmations, greaterThanOrEqualTo(0));
          expect(utxo.isConfirmed, utxo.confirmations > 0);
          // labels are read-only BIP329 strings the tile renders; the field is
          // always present (possibly empty) — assert the contract, not content.
          expect(utxo.labels, isNotNull);
        }
      });

      test('frozen coins are excluded from every PSBT build (D7)', () async {
        final utxos = await utxoRepository.getWalletUtxos(walletId: wallet.id);
        if (utxos.isEmpty) {
          markTestSkipped('testnet wallet $wallet is unfunded');
          return;
        }

        // Freeze EVERY coin. A decode-free way to prove D7 exclusion is real:
        // if frozen coins were still selectable, a drain would build fine; with
        // all coins in the unspendable set, BDK has nothing to pick and the
        // build must fail with NoSpendableUtxoException. (Asserting a specific
        // outpoint's absence would need PSBT-input decoding; this is the same
        // guarantee without that machinery.)
        final allOutpoints = utxos
            .map((u) => (txId: u.txId, vout: u.vout))
            .toList();
        await utxoRepository.freezeUtxos(
          walletId: wallet.id,
          outpoints: allOutpoints,
        );
        addTearDown(
          () => utxoRepository.unfreezeUtxos(
            walletId: wallet.id,
            outpoints: allOutpoints,
          ),
        );

        final receive = await addressRepository.generateNewReceiveAddress(
          walletId: wallet.id,
        );

        // Drain to self: selection would otherwise sweep every coin. With all
        // frozen, the prepare must throw NoSpendableUtxoException.
        await expectLater(
          prepareBitcoinSendUsecase.execute(
            walletId: wallet.id,
            address: receive.address,
            drain: true,
            networkFee: NetworkFee.relativeFromSatPerVbyte(2),
          ),
          throwsA(isA<NoSpendableUtxoException>()),
        );
      });
    },
    skip: hasFunds
        ? false
        : 'requires funded testnet wallet (set TEST_ALICE_MNEMONIC)',
  );
}
