import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:preferences/preferences.dart';
import 'package:address_view/address_view.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:signers/storage.dart';
import 'package:sync/sync.dart' as native;
import 'package:receive/receive.dart';
import 'package:receive/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Reporter extends Mock implements LoggerReporter {}

class _Environment extends Mock implements ActiveEnvironmentReader {}

class _Inventory extends Mock implements WalletInventory {}

class _Devices extends Mock implements SignerDevices {}

class _MockGetReceiveAddressUsecase extends Mock implements AddressView {}

class _MockGetAddressAtIndexUsecase extends Mock implements AddressView {}

/// Deliberately shaped like a real leak: a driver string with a filesystem
/// path in it. It must reach `logMessage` and nothing else.
const _rawReason =
    'DriftRemoteException: database is locked at /data/user/0/app.sqlite';

WalletAddress _address() => WalletAddress(
  walletId: 'w1',
  index: 0,
  address: 'bc1qtest',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('GetReceiveWalletsUsecase', () {
    final registration = walletRegistrationForTesting(
      id: 'w1',
      network: BitcoinNetwork.testnet,
      isDefault: true,
    );
    late _Environment preferences;
    late _Inventory inventory;
    late _Devices devices;
    late GetReceiveWalletsUsecase read;
    late List<native.WalletKey> requested;

    setUp(() {
      preferences = _Environment();
      inventory = _Inventory();
      devices = _Devices();
      requested = [];
      when(() => preferences.readActiveEnvironment())
          .thenAnswer((_) async => const Ok(Environment.testnet));
      when(() => devices.read('w1')).thenAnswer((_) async => const Ok(null));
      read = GetReceiveWalletsUsecase(preferences, inventory, (key) async {
        requested.add(key);
        return const Err(native.SyncNotFoundFailure());
      }, devices);
    });

    test(
      'a missing balance keeps the exact-network wallet eligible for receive',
      () async {
        when(() => inventory.walletsForNetwork(BitcoinNetwork.testnet))
            .thenAnswer(
              (_) async => Ok(walletSelectionForTesting([registration])),
            );
        final result = await read.execute(onlyBitcoin: true);
        final wallet =
            (result as Ok<List<ReceiveWallet>, ReceiveFailure>).value.single;
        expect(wallet.id, 'w1');
        expect(wallet.network, BitcoinNetwork.testnet);
        expect(wallet.balanceSat, isNull);
        expect(
          requested.single,
          native.WalletKey(id: 'w1', network: BitcoinNetwork.testnet),
        );
      },
    );

    test('a locked inventory must not resurrect an entry wallet', () async {
      when(() => inventory.readWallet('w1'))
          .thenAnswer((_) async => const Err(FetchSecretFailure()));
      final result = await read.resolveEntry(
        const ReceiveWallet(
          id: 'w1',
          network: BitcoinNetwork.testnet,
          signsLocally: true,
          scriptType: ScriptType.bip84,
        ),
      );
      expect(result, isA<Err<ReceiveWallet, ReceiveFailure>>());
      expect(requested, isEmpty);
      verifyZeroInteractions(devices);
    });

    test('a same-id wallet on the wrong network is not loaded', () async {
      when(() => inventory.readWallet('w1'))
          .thenAnswer((_) async => Ok(registration));
      final result = await read.resolveEntry(
        const ReceiveWallet(
          id: 'w1',
          network: LiquidNetwork.testnet,
          signsLocally: true,
          scriptType: ScriptType.bip84,
        ),
      );
      expect(result, isA<Err<ReceiveWallet, ReceiveFailure>>());
      expect(requested, isEmpty);
    });
  });

  group('PrepareReceiveAddressUsecase', () {
    test('forwards the address on success', () async {
      final inner = _MockGetReceiveAddressUsecase();
      when(
        () => inner.receiveAddress(
          walletId: any(named: 'walletId'),
          advance: any(named: 'advance'),
        ),
      ).thenAnswer((_) async => Ok(_address()));

      final result = await PrepareReceiveAddressUsecase(inner)
          .execute(walletId: 'w1');

      expect(result, isA<Ok<WalletAddress, ReceiveFailure>>());
    });

    test(
      'maps a typed address failure without leaking its diagnostics',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'receive-boundary-',
        );
        final reporter = _Reporter();
        await initializeLogging(directory: directory, reporter: reporter);
        addTearDown(() async {
          await log.flush();
          await directory.delete(recursive: true);
        });
        final inner = _MockGetReceiveAddressUsecase();
        when(
          () => inner.receiveAddress(
            walletId: any(named: 'walletId'),
            advance: any(named: 'advance'),
          ),
        ).thenAnswer(
          (_) async =>
              const Err(AddressViewAddressesUnavailableFailure(_rawReason)),
        );

        final result = await PrepareReceiveAddressUsecase(inner)
            .execute(walletId: 'w1');

        final lines = await log.readLogs();
        expect(lines.map((line) => line.split('\t').sublist(1, 3)), [
          ['FINE', 'Logs created'],
          ['WARNING', 'Receive address failed reason=unavailable'],
        ]);
        expect(lines.join(), isNot(contains(_rawReason)));
        expect(lines.join(), isNot(contains('app.sqlite')));
        verifyZeroInteractions(reporter);

        switch (result) {
          case Ok():
            fail('an unavailable address must not be reported as an address');
          case Err(:final failure):
            // Dedicated variant: the user gets an actionable "could not prepare
            // an address" message rather than the generic one.
            expect(failure, isA<ReceiveAddressUnavailableFailure>());
            expect(failure.logMessage, 'unavailable');
        }
      },
    );
  });

  group('GetReceiveAddressAtIndexUsecase', () {
    test('maps an unavailable address and discards foreign details', () async {
      final inner = _MockGetAddressAtIndexUsecase();
      when(
        () => inner.at(
          walletId: any(named: 'walletId'),
          index: any(named: 'index'),
        ),
      ).thenAnswer(
        (_) async =>
            const Err(AddressViewAddressesUnavailableFailure(_rawReason)),
      );

      final result = await GetReceiveAddressAtIndexUsecase(inner)
          .execute(walletId: 'w1', index: 1);

      switch (result) {
        case Ok():
          fail('a failed lookup must not be reported as an address');
        case Err(:final failure):
          expect(failure, isA<ReceiveAddressUnavailableFailure>());
          expect(failure.logMessage, isNot(contains('app.sqlite')));
      }
    });
  });
}
