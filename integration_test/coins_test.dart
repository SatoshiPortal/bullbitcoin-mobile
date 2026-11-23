import 'initialization_result.dart';

import 'package:primitives/primitives.dart'
    show BitcoinTransactionRecipient, Err, Ok, Result;
import 'package:primitives/primitives.dart' as primitives show Network;

import 'dart:io';

import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:fees/fees.dart';
import 'package:secrets/secrets.dart';
import 'package:preferences/preferences.dart';
import 'package:labels/labels.dart';
import 'package:labels/migration.dart';
import 'package:labels/setup.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:sync/sync.dart' show CoinFreezes;
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:address_view/address_view.dart';
import 'package:bb_mobile/features/coins/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/init.dart';
import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:sync/sync.dart' as sync;
import 'package:flutter_test/flutter_test.dart';

import 'developer_network.dart';
import 'funded_testnet_wallet.dart';

// Integration tests for the Coins / UTXO view + freeze (issue #760).
//
// Covers the §7.1 acceptance criteria:
//   1. Freeze persists across restart — freeze an outpoint, re-init the
//      encrypted Labels owner, the outpoint is still frozen. Funds-free: this
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
  if (!isInitialized) {
    requireSuccessfulBullInitialization(await Bull.init());
  }

  final frozenDatasource = locator<CoinFreezes>();
  final utxoRepository = locator<WalletUtxoRepository>();

  group('Coins / freeze persistence (funds-free)', () {
    const walletId = 'coins-integration-test-wallet';
    const outpoint = (
      txId: '0000000000000000000000000000000000000000000000000000000000000001',
      vout: 0,
    );

    Future<void> clear() async {
      await frozenDatasource.unfreeze([outpoint]);
    }

    setUp(clear);
    tearDown(clear);

    test('freeze is durable across a restart', () async {
      final dir = await Directory.systemTemp.createTemp('coins_restart');
      addTearDown(() => dir.delete(recursive: true));
      final dbFile = File('${dir.path}/labels.sqlite');
      final gate = NativeFileGate(File('${dir.path}/labels.lock'));
      final exclusive = await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      ) as ExclusiveAdmission;
      try {
        final prepared = await LabelsImport(file: dbFile)
            .prepare(exclusive, OwnerOrigin.fresh);
        final owner = switch (prepared) {
          Ok(:final value) => value,
          Err(:final failure) => fail('prepare Labels: ${failure.runtimeType}'),
        };
        expect(await owner.initializeFresh(), isA<Ok>());
      } finally {
        await exclusive.close();
      }

      Future<T> withReopenedLabels<T>(
        Future<T> Function(CoinFreezes) action,
      ) async {
        final admission = await gate.acquire(
          exclusive: false,
          timeout: Duration.zero,
        ) as RuntimeAdmission;
        try {
          late final sync.Sync runtime;
          final opened = await Labels.open(
            file: dbFile,
            admission: admission,
            sync: () async => runtime,
            openWallet: (_) async => fail('no wallet needed for freezes'),
          );
          final labels = switch (opened) {
            Ok(:final value) => value,
            Err(:final failure) => fail('open Labels: ${failure.runtimeType}'),
          };
          runtime = sync.Sync.foreground(
            documentsDirectory: dir.path,
            catalog: const _NoCatalog(),
            reservedAddresses: const _NoReserved(),
            freezes: labels.freezes,
            inputReservations: _NoInputReservations(),
            connections: const _NoConnections(),
          );
          try {
            return await action(CoinFreezes(sync: () async => runtime));
          } finally {
            await runtime.close();
          }
        } finally {
          await admission.close();
        }
      }

      await withReopenedLabels(
        (freezes) => freezes.freezeAttributed([
          sync.FrozenOutpoint(outpoint, origin: walletId),
        ]),
      );
      final afterRestart = await withReopenedLabels(
        (freezes) => freezes.getFrozenOutpoints(),
      );

      expect(
        afterRestart,
        contains(outpoint),
        reason: 'a user-frozen outpoint must persist across an app restart',
      );
    });

    test('unfreeze removes the freeze row', () async {
      await frozenDatasource.freezeAttributed([
        sync.FrozenOutpoint(outpoint, origin: walletId),
      ]);
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
  const mnemonicDefine = String.fromEnvironment('TEST_ALICE_MNEMONIC');
  final mnemonic = mnemonicDefine.isNotEmpty
      ? mnemonicDefine
      : Platform.environment['TEST_ALICE_MNEMONIC'];
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
      late final AddressView addressRepository;
      late final PrepareBitcoinSendUsecase prepareBitcoinSendUsecase;
      late Wallet wallet;

      setUpAll(() async {
        walletRepository = locator<WalletRepository>();
        addressRepository = locator<AddressView>();
        prepareBitcoinSendUsecase = locator<PrepareBitcoinSendUsecase>();

        // Testnet is a developer network: enable it as a user would.
        // Restored when the group ends, even if this setup fails.
        await selectDeveloperNetwork(Environment.testnet);
        wallet = await openFundedTestnetWallet(
          mnemonic: mnemonic ?? fail('missing Alice fixture'),
          secrets: locator<Secrets>(),
          wallets: walletRepository,
        );
        // Fail fast: a funding sync that failed would otherwise surface as a
        // confusing balance assertion further down.
        expect(
          await walletRepository.getWallets(sync: true),
          isA<Ok<List<Wallet>, WalletFailure>>(),
        );
      });

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

      test('a manual drain spends exactly the selected outpoint', () async {
        final utxos = await utxoRepository.getWalletUtxos(walletId: wallet.id);
        final spendable = utxos.where((utxo) => !utxo.isFrozen).toList();
        if (spendable.length < 2) {
          markTestSkipped('requires at least two testnet UTXOs');
          return;
        }
        final selected = spendable.reduce(
          (largest, candidate) =>
              candidate.amountSat > largest.amountSat ? candidate : largest,
        );
        final receiveResult = await addressRepository.receiveAddress(
          walletId: wallet.id,
          advance: true,
        );
        final receive = switch (receiveResult) {
          Ok(:final value) => value,
          Err(:final failure) => fail(failure.runtimeType.toString()),
        };

        final preparationResult = await prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          recipients: [
            BitcoinTransactionRecipient.remainder(address: receive.address),
          ],
          selectedInputs: [selected],
          networkFee: NetworkFee.relativeFromSatPerVbyte(2),
        );
        final prepared = switch (preparationResult) {
          Ok(:final value) => value,
          Err(:final failure) => fail(
            'Bitcoin preparation failed: ${failure.runtimeType}',
          ),
        };

        final inputs = bdk.Psbt(psbtBase64: prepared.unsignedPsbt)
            .extractTx()
            .input();
        expect(inputs, hasLength(1));
        expect(inputs.single.previousOutput.txid.toString(), selected.txId);
        expect(inputs.single.previousOutput.vout, selected.vout);
      });

      test('a partly frozen manual selection fails closed', () async {
        final utxos = await utxoRepository.getWalletUtxos(walletId: wallet.id);
        final spendable = utxos.where((utxo) => !utxo.isFrozen).toList();
        if (spendable.length < 2) {
          markTestSkipped('requires at least two testnet UTXOs');
          return;
        }
        final selection = spendable.take(2).toList();
        final frozenOutpoint = (
          txId: selection.first.txId,
          vout: selection.first.vout,
        );
        await utxoRepository.freezeUtxos(
          walletId: wallet.id,
          outpoints: [frozenOutpoint],
        );
        addTearDown(
          () => utxoRepository.unfreezeUtxos(
            walletId: wallet.id,
            outpoints: [frozenOutpoint],
          ),
        );
        final receiveResult = await addressRepository.receiveAddress(
          walletId: wallet.id,
          advance: true,
        );
        final receive = switch (receiveResult) {
          Ok(:final value) => value,
          Err(:final failure) => fail(failure.runtimeType.toString()),
        };

        await expectLater(
          prepareBitcoinSendUsecase.execute(
            walletId: wallet.id,
            recipients: [
              BitcoinTransactionRecipient.remainder(address: receive.address),
            ],
            selectedInputs: selection,
            networkFee: NetworkFee.relativeFromSatPerVbyte(2),
          ),
          completion(
            isA<Err<Object?, WalletFailure>>().having(
              (result) => result.failure,
              'failure',
              isA<WalletSelectedInputsUnavailableFailure>(),
            ),
          ),
        );
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
        // build must fail with WalletNoSpendableInputsFailure. (Asserting a specific
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

        final receiveResult = await addressRepository.receiveAddress(
          walletId: wallet.id,
          advance: true,
        );
        final receive = switch (receiveResult) {
          Ok(:final value) => value,
          Err(:final failure) => fail(failure.runtimeType.toString()),
        };

        // Drain to self: selection would otherwise sweep every coin. With all
        // frozen, the prepare must return WalletNoSpendableInputsFailure.
        await expectLater(
          prepareBitcoinSendUsecase.execute(
            walletId: wallet.id,
            recipients: [
              BitcoinTransactionRecipient.remainder(address: receive.address),
            ],
            networkFee: NetworkFee.relativeFromSatPerVbyte(2),
          ),
          completion(
            isA<Err<Object?, WalletFailure>>().having(
              (result) => result.failure,
              'failure',
              isA<WalletNoSpendableInputsFailure>(),
            ),
          ),
        );
      });
    },
    skip: hasFunds
        ? false
        : 'requires funded testnet wallet (set TEST_ALICE_MNEMONIC)',
  );
}

final class _NoCatalog implements sync.WalletCatalogPort {
  const _NoCatalog();

  @override
  Future<Result<sync.PublicWalletDescriptor, sync.SyncFailure>> find(
    sync.WalletKey key,
  ) async => const Err(sync.SyncNotFoundFailure());

  @override
  Future<Result<List<sync.PublicWalletDescriptor>, sync.SyncFailure>>
  list() async => const Ok([]);
}

final class _NoReserved implements sync.ReservedAddressPort {
  const _NoReserved();

  @override
  Future<Result<bool, sync.SyncFailure>> isReserved(
    sync.WalletKey key,
    String address,
  ) async => const Ok(false);
}

/// The test broadcasts nothing.
final class _NoConnections implements sync.WalletConnectionPort {
  const _NoConnections();

  @override
  Future<Result<T, sync.SyncFailure>> run<T>({
    required primitives.Network network,
    required Future<Result<T, sync.SyncFailure>> Function(sync.WalletConnection)
    operation,
    required bool Function(sync.SyncFailure) mayRetry,
  }) async => const Err(sync.SyncConnectionFailure());
}

final class _NoInputReservations implements sync.InputReservationPort {
  @override
  Future<Result<List<sync.InputReservation>, sync.SyncFailure>>
  reservations() async => const Ok([]);
}
