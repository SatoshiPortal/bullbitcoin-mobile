import 'dart:io';

import 'package:ark/funding.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:spend/setup.dart';
import 'package:spend/spend.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart';
import 'package:secrets/testing.dart' show unlockedSessionAuthority;

// Public BIP84 descriptors of the published BIP39 vector "abandon ... about"
// (account m/84'/1'/0'): no private key, no application custody material.
const _origin = "[73c5da0a/84'/1'/0']";
const _xpub =
    'tpubDC8msFGeGuwnKG9Upg7DM2b4DaRqg3CUZa5g8v2SRQ6K4NSkxUgd7HsL2XVWbVm39y'
    'BA4LAxysQAm397zwQSQoQgewGiYZqrA9DsP4zbQ1M';
final _key = WalletKey(
  id: 'published-vector:regtest',
  network: BitcoinNetwork.regtest,
);
final _descriptor = BitcoinWalletDescriptor(
  key: _key,
  scriptType: ScriptType.bip84,
  origin: 'wpkh($_origin)',
  externalDescriptor: 'wpkh($_origin$_xpub/0/*)',
  internalDescriptor: 'wpkh($_origin$_xpub/1/*)',
);

// First BIP84 mainnet address of the same vector.
const _mainnetAddress = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';

final _absent = (txId: 'aa' * 32, vout: 0);

void main() {
  late Directory directory;
  late MemoryFreezeStore freezes;
  late _Reservations reservations;
  late _Connections connections;
  late WalletNativeRuntime runtime;
  late Spend spend;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('spend-watch-only-');
    freezes = MemoryFreezeStore();
    reservations = _Reservations();
    connections = _Connections();
    runtime = WalletNativeRuntime.open(
      catalog: _Catalog(),
      reserved: _NoReservedAddresses(),
      inputReservations: reservations,
      deleteCatalogEntry: (_) async => throw StateError('Unexpected deletion'),
      sync: ElectrumSync(
        connections: connections,
        documentsDirectory: () async => directory.path,
        readRevision: (_) async => throw StateError('Unexpected revision read'),
      ),
      documentsDirectory: () async => directory.path,
      freezes: freezes,
      connections: connections,
    );
    spend = Spend.open(
      sync: runtime,
      secrets: Secrets(
        authority: unlockedSessionAuthority(),
        scratchDirectory: () async => directory.path,
      ),
      arkFunding: const ArkFundingSigningGuard(authority: null),
      catalog: _WatchOnlyCatalog(),
    );
  });

  tearDown(() async {
    expect(await runtime.close(), isA<Ok>());
    await directory.delete(recursive: true);
    expect(connections.networks, isEmpty);
  });

  group('Bitcoin spend preconditions without a selection', () {
    test('pass when freezes and Payjoin reservations are readable', () async {
      for (final selected in <Set<Outpoint>?>[null, {}]) {
        expect(
          await spend.validateBitcoinSelection(
            walletId: _key.id,
            selectedInputs: selected,
          ),
          isA<Ok<void, SpendFailure>>(),
        );
      }
      expect(reservations.reads, 2);
    });

    test('refuse an unreadable freeze store', () async {
      freezes.failure = const SyncStorageFailure();
      for (final selected in <Set<Outpoint>?>[null, {}]) {
        expect(
          await spend.validateBitcoinSelection(
            walletId: _key.id,
            selectedInputs: selected,
          ),
          _failure<void, SpendUnavailableFailure>(),
        );
      }
      expect(reservations.reads, 0);
    });

    test('refuse unreadable Payjoin reservations', () async {
      reservations.failure = const SyncStorageFailure();
      expect(
        await spend.validateBitcoinSelection(walletId: _key.id),
        _failure<void, SpendUnavailableFailure>(),
      );
    });
  });

  test('a selected coin the wallet does not hold is refused', () async {
    expect(
      await spend.validateBitcoinSelection(
        walletId: _key.id,
        selectedInputs: {_absent},
      ),
      _failure<void, SpendSelectedInputsUnavailableFailure>(),
    );
    expect(
      await spend.prepareBitcoin(
        walletId: _key.id,
        recipients: [
          BitcoinTransactionRecipient.remainder(
            address: await _receive(runtime),
          ),
        ],
        networkFee: const RelativeFee(500),
        selectedInputs: {_absent},
        selectedOnly: true,
      ),
      _failure<PreparedBitcoinSpend, SpendSelectedInputsUnavailableFailure>(),
    );
  });

  group('Bitcoin preparation', () {
    test('refuses an amount above the Bitcoin supply', () async {
      expect(
        await spend.prepareBitcoin(
          walletId: _key.id,
          recipients: [
            BitcoinTransactionRecipient.fixed(
              address: _mainnetAddress,
              amountSat: Sats(Sats.maxBitcoinSupply + BigInt.one),
            ),
          ],
          networkFee: const RelativeFee(500),
        ),
        _failure<PreparedBitcoinSpend, SpendInvalidRequestFailure>(),
      );
    });

    test('refuses selected-only spending without a selection', () async {
      expect(
        await spend.prepareBitcoin(
          walletId: _key.id,
          recipients: [
            BitcoinTransactionRecipient.remainder(address: _mainnetAddress),
          ],
          networkFee: const RelativeFee(500),
          selectedInputs: {},
          selectedOnly: true,
        ),
        _failure<PreparedBitcoinSpend, SpendNoSpendableInputsFailure>(),
      );
    });

    test('refuses a destination of another network', () async {
      expect(
        await spend.prepareBitcoin(
          walletId: _key.id,
          recipients: [
            BitcoinTransactionRecipient.fixed(
              address: _mainnetAddress,
              amountSat: Sats.fromInt(10000),
            ),
          ],
          networkFee: const RelativeFee(500),
        ),
        _failure<PreparedBitcoinSpend, SpendNetworkMismatchFailure>(),
      );
    });

    test('reports insufficient funds from the real wallet build', () async {
      expect(
        await spend.prepareBitcoin(
          walletId: _key.id,
          recipients: [
            BitcoinTransactionRecipient.fixed(
              address: await _receive(runtime),
              amountSat: Sats.fromInt(10000),
            ),
          ],
          networkFee: const RelativeFee(500),
        ),
        _failure<PreparedBitcoinSpend, SpendInsufficientFundsFailure>(),
      );
    });
  });

  group('Bitcoin fee presets', () {
    test('an unaffordable preset has no preview, not a failure', () async {
      final result = await spend.previewBitcoinFeePresets(
        walletId: _key.id,
        recipients: [
          BitcoinTransactionRecipient.fixed(
            address: await _receive(runtime),
            amountSat: Sats.fromInt(10000),
          ),
        ],
        presets: const FeeOptions(
          fastest: RelativeFee(750),
          economic: RelativeFee(500),
          slow: RelativeFee(250),
          minRelay: RelativeFee(25),
        ),
        replaceByFee: true,
        selectedInputs: {},
      );
      expect(
        result,
        isA<Ok<Map<FeeSelection, BitcoinSpendPreview?>, SpendFailure>>().having(
          (ok) => ok.value,
          'slots',
          {
            FeeSelection.fastest: null,
            FeeSelection.economic: null,
            FeeSelection.slow: null,
          },
        ),
      );
    });

    test('a wallet that cannot be resolved fails every preset', () async {
      final result = await spend.previewBitcoinFeePresets(
        walletId: 'unknown',
        recipients: [
          BitcoinTransactionRecipient.remainder(address: _mainnetAddress),
        ],
        presets: const FeeOptions(
          fastest: RelativeFee(750),
          economic: RelativeFee(500),
          slow: RelativeFee(250),
          minRelay: RelativeFee(25),
        ),
        replaceByFee: true,
        selectedInputs: {},
      );
      expect(
        result,
        _failure<
          Map<FeeSelection, BitcoinSpendPreview?>,
          SpendUnavailableFailure
        >(),
      );
    });
  });
}

Future<String> _receive(WalletNativeRuntime runtime) async =>
    switch (await runtime.receive(_key)) {
      Ok(:final value) => value.address,
      Err(:final failure) => throw StateError('No receive address: $failure'),
    };

Matcher _failure<R, F extends SpendFailure>() => isA<Err<R, SpendFailure>>()
    .having((error) => error.failure, 'failure', isA<F>());

final class _Catalog implements WalletCatalogPort {
  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async => key == _key ? Ok(_descriptor) : const Err(SyncNotFoundFailure());

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      Ok([_descriptor]);
}

/// Watch-only: Spend never receives a software signer for this wallet.
final class _WatchOnlyCatalog implements SpendCatalog {
  @override
  Future<Result<SpendWallet, SpendFailure>> resolve(String walletId) async =>
      walletId == _key.id
      ? Ok((key: _key, signer: null))
      : const Err(SpendUnavailableFailure());
}

final class _NoReservedAddresses implements ReservedAddressPort {
  @override
  Future<Result<bool, SyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const Ok(false);
}

final class _Reservations implements InputReservationPort {
  SyncFailure? failure;
  int reads = 0;

  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async {
    reads++;
    return switch (failure) {
      final failure? => Err(failure),
      null => const Ok([]),
    };
  }
}

final class _Connections implements WalletConnectionPort {
  final networks = <Network>[];

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    networks.add(network);
    return const Err(SyncConnectionFailure());
  }
}
