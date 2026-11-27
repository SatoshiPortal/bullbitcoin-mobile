import 'dart:io';

import 'package:address_view/address_view.dart';
import 'package:bb_mobile/init.dart';
import 'package:bb_mobile/locator.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labels/labels.dart';
import 'package:labels/migration.dart';
import 'package:labels/setup.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart' show SecretsInventory;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spend/spend.dart';
import 'package:sync/sync.dart' as sync;
import 'package:sync/write.dart' show WalletNativeRuntime;

import 'developer_network.dart';
import 'funded_regtest_wallet.dart';
import 'funded_testnet_wallet.dart';
import 'initialization_result.dart';

// Integration tests for the Coins / UTXO view + freeze (issue #760).
//
// Covers the §7.1 acceptance criteria:
//   1. Freeze persists across restart — freeze an outpoint, re-init the
//      encrypted Labels owner, the outpoint is still frozen. Funds-free: this
//      is the load-bearing persistence guarantee and runs anywhere.
//   2. A frozen coin is never spent — freeze a real wallet outpoint, have
//      Spend build a PSBT, assert the frozen outpoint is
//      absent from the PSBT inputs (the D7 guarantee). Uses a local regtest
//      wallet, or a funded testnet wallet when configured.
//   3. The list surfaces confirmed vs unconfirmed + BIP329 labels — reads the
//      wallet's real UTXOs and asserts the confirmations/labels fields the view
//      renders. Uses the same funded wallet.
//
// Run via `make integration-test` (auto-aggregated by tools/gen_all_test.dart).
Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) {
    if (localRegtest) {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setInt('wizard_pending_version', 1) ||
          !await preferences.setString('wizard_pending_network', 'testnet')) {
        throw StateError('Could not stage the pending network');
      }
    }
    requireSuccessfulBullInitialization(
      await Bull.init(
        initialNetwork: localRegtest ? Environment.regtest : null,
      ),
    );
    if (localRegtest) {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getString('wizard_pending_network') != null) {
        throw StateError('Pending network was not cleared');
      }
    }
  }

  group('Coins / freeze persistence (funds-free)', () {
    const walletId = 'coins-integration-test-wallet';
    const outpoint = (
      txId: '0000000000000000000000000000000000000000000000000000000000000001',
      vout: 0,
    );

    late final WalletNativeRuntime native;

    setUpAll(() {
      native = locator<WalletNativeRuntime>();
    });

    Future<void> clear() async {
      requireValue(
        await native.unfreezeOutpoints([outpoint]),
        'clear the fixture freeze',
      );
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
        try {
          requireValue(await owner.initializeFresh(), 'initialize Labels');
        } finally {
          requireValue(await owner.close(), 'close prepared Labels');
        }
      } finally {
        await exclusive.close();
      }

      Future<T> withReopenedLabels<T>(
        Future<T> Function(sync.SyncCoins) action,
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
            listAttributedFreezes: () => runtime.coins.listFrozen(),
            freezeAttributedOutpoints: (_) => fail('no writes needed'),
            openWallet: (_) async => fail('no wallet needed for freezes'),
            readInSession: (_) async =>
                fail('no ownership read needed for freezes'),
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
            return await action(runtime.coins);
          } finally {
            await runtime.close();
            requireValue(await labels.close(), 'close Labels');
          }
        } finally {
          await admission.close();
        }
      }

      await withReopenedLabels((freezes) async {
        requireValue(
          await freezes.freeze(outpoint, origin: walletId),
          'freeze the fixture outpoint',
        );
      });
      final afterRestart = await withReopenedLabels((freezes) async {
        return requireValue(
          await freezes.listFrozen(),
          'read reopened freezes',
        );
      });

      expect(
        afterRestart.map((row) => row.outpoint),
        contains(outpoint),
        reason: 'a user-frozen outpoint must persist across an app restart',
      );
    });

    test('unfreeze removes the freeze row', () async {
      requireValue(
        await native.freezeAttributedOutpoints([
          sync.FrozenOutpoint(outpoint, origin: walletId),
        ]),
        'freeze the fixture outpoint',
      );
      requireValue(
        await native.unfreezeOutpoints([outpoint]),
        'unfreeze the outpoint',
      );
      // Freeze is matched by outpoint across all wallets — the global set must
      // no longer carry it after unfreeze.
      final remaining = requireValue(
        await native.listAttributedFreezes(),
        'read freezes',
      );
      expect(remaining.map((row) => row.outpoint), isNot(contains(outpoint)));
    });
  });

  // -------------------------------------------------------------------------
  // The local profile provisions its own confirmed UTXOs. Outside that
  // profile the existing funded-testnet fixture remains optional.
  // -------------------------------------------------------------------------
  const mnemonicDefine = String.fromEnvironment('TEST_ALICE_MNEMONIC');
  final mnemonic = localRegtest
      ? null
      : mnemonicDefine.isNotEmpty
      ? mnemonicDefine
      : Platform.environment['TEST_ALICE_MNEMONIC'];
  final hasFunds = localRegtest || (mnemonic != null && mnemonic.isNotEmpty);

  group(
    'Coins / freeze enforcement (funded wallet)',
    () {
      late final AddressView addresses;
      late final Spend spend;
      late final sync.Wallet wallet;

      setUpAll(() async {
        addresses = locator<AddressView>();
        spend = locator<Spend>();
        if (localRegtest) {
          final settings = requireValue(
            await locator<Preferences>().fetch(),
            'read startup environment',
          );
          expect(settings.environment, Environment.regtest);
          expect(settings.activeNetwork, NetworkEnv.regtest);
          wallet = await fundedRegtestWallet();
          return;
        }
        // Testnet is a developer network: enable it as a user would.
        // Restored when the group ends, even if this setup fails.
        await selectDeveloperNetwork(Environment.testnet);
        final key = await openFundedTestnetWallet(
          mnemonic: mnemonic ?? fail('missing Alice fixture'),
          secrets: locator<Secrets>(),
          inventory: locator<SecretsInventory>(),
          native: locator<WalletNativeRuntime>(),
        );
        wallet = await syncFundedTestnetWallet(key);
      });

      sync.CoinList readCoins() =>
          requireValue(wallet.coins.now.latest, 'read fixture coins');

      Future<void> freezeForTest(Outpoint outpoint) async {
        requireValue(
          await wallet.coins.freeze(outpoint),
          'freeze fixture coin',
        );
        addTearDown(() async {
          requireValue(
            await wallet.coins.unfreeze(outpoint),
            'unfreeze fixture coin',
          );
        });
      }

      Future<String> issueReceiveAddress() async => requireValue(
        await addresses.receiveAddress(walletId: wallet.key.id, advance: true),
        'issue a fixture receive address',
      ).address;

      test('list surfaces confirmations and labels per UTXO', () async {
        final utxos = readCoins();
        if (localRegtest) expect(utxos, isNotEmpty);
        if (utxos.isEmpty) {
          // The mnemonic is set but the testnet wallet has no UTXOs (faucet
          // funds expire). Skip rather than hard-fail CI — the D7 exclusion
          // guarantee is covered deterministically by the prepare-send unit
          // tests; this group is the live, best-effort on-chain confirmation.
          markTestSkipped('testnet wallet is unfunded');
          return;
        }

        final history = requireValue(
          wallet.history.now.latest,
          'read fixture history',
        );
        for (final coin in utxos) {
          expect(coin, isA<sync.BitcoinCoin>());
          final bitcoin = coin as sync.BitcoinCoin;
          final transaction = history.singleWhere(
            (transaction) => transaction.txid == coin.outpoint.txId,
          );
          expect(bitcoin.confirmations, greaterThanOrEqualTo(0));
          expect(
            bitcoin.confirmations > 0,
            transaction.confirmationTime != null,
          );
        }

        final labels = locator<Labels>();
        final (:txId, :vout) = utxos.first.outpoint;
        final reference = '$txId:$vout';
        final stored = requireValue(
          await labels.store(
            NewLabel(
              type: LabelType.output,
              label: 'Coins integration fixture',
              reference: reference,
            ),
          ),
          'label the fixture outpoint',
        );
        addTearDown(() async {
          requireValue(
            await labels.trash(stored.id),
            'remove the fixture label',
          );
        });
        final found = requireValue(
          await labels.fetch(reference: reference),
          'read the fixture label',
        );
        expect(found.map((label) => label.id), contains(stored.id));
      });

      test('a manual drain spends exactly the selected outpoint', () async {
        final utxos = readCoins();
        final spendable = utxos.where((utxo) => !utxo.frozen).toList();
        if (localRegtest) expect(spendable.length, greaterThanOrEqualTo(2));
        if (spendable.length < 2) {
          markTestSkipped('requires at least two testnet UTXOs');
          return;
        }
        final selected = spendable.reduce(
          (largest, candidate) =>
              candidate.amountSat > largest.amountSat ? candidate : largest,
        );
        final address = await issueReceiveAddress();
        final prepared = requireValue(
          await spend.prepareBitcoin(
            walletId: wallet.key.id,
            recipients: [
              BitcoinTransactionRecipient.remainder(address: address),
            ],
            selectedInputs: {selected.outpoint},
            selectedOnly: true,
            networkFee: NetworkFee.relativeFromSatPerVbyte(2),
          ),
          'prepare the selected-coin drain',
        );
        final psbt = requireValue(
          sync.inspectBitcoinPsbt(prepared.unsignedPsbt),
          'inspect the selected-coin drain',
        );
        expect(psbt.inputs.map((input) => input.outpoint), [selected.outpoint]);
      });

      test('a partly frozen manual selection fails closed', () async {
        final utxos = readCoins();
        final spendable = utxos.where((utxo) => !utxo.frozen).toList();
        if (localRegtest) expect(spendable.length, greaterThanOrEqualTo(2));
        if (spendable.length < 2) {
          markTestSkipped('requires at least two testnet UTXOs');
          return;
        }
        final selection = spendable
            .take(2)
            .map((coin) => coin.outpoint)
            .toSet();
        await freezeForTest(selection.first);
        final address = await issueReceiveAddress();

        final prepared = await spend.prepareBitcoin(
          walletId: wallet.key.id,
          recipients: [BitcoinTransactionRecipient.remainder(address: address)],
          selectedInputs: selection,
          selectedOnly: true,
          networkFee: NetworkFee.relativeFromSatPerVbyte(2),
        );
        expect(
          prepared,
          isA<Err<PreparedBitcoinSpend, SpendFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<SpendSelectedInputsUnavailableFailure>(),
          ),
        );
      });

      test('frozen coins are excluded from every PSBT build (D7)', () async {
        final utxos = readCoins();
        if (localRegtest) expect(utxos, isNotEmpty);
        if (utxos.isEmpty) {
          markTestSkipped('testnet wallet is unfunded');
          return;
        }

        // A drain would sweep the whole wallet if frozen coins were selectable.
        for (final coin in utxos) {
          await freezeForTest(coin.outpoint);
        }
        final address = await issueReceiveAddress();
        final prepared = await spend.prepareBitcoin(
          walletId: wallet.key.id,
          recipients: [BitcoinTransactionRecipient.remainder(address: address)],
          networkFee: NetworkFee.relativeFromSatPerVbyte(2),
        );
        expect(
          prepared,
          isA<Err<PreparedBitcoinSpend, SpendFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<SpendNoSpendableInputsFailure>(),
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
    required Network network,
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
