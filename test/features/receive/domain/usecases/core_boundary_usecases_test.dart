import 'package:primitives/primitives.dart' show ScriptType;

import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:address_view/address_view.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:receive/receive.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_address_at_index_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_wallets_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/prepare_receive_address_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' hide Network, ScriptType;

class _Reporter extends Mock implements LoggerReporter {}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

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

Wallet _wallet() => Wallet(
  origin: 'w1',
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(50000),
  confirmedBalanceSat: BigInt.from(50000),
);

void main() {
  group('GetReceiveWalletsUsecase', () {
    test('forwards the wallets on success', () async {
      final inner = _MockGetWalletsUsecase();
      when(
        () => inner.execute(
          onlyDefaults: any(named: 'onlyDefaults'),
          onlyBitcoin: any(named: 'onlyBitcoin'),
          onlyLiquid: any(named: 'onlyLiquid'),
          sync: any(named: 'sync'),
        ),
      ).thenAnswer((_) async => Ok([_wallet()]));

      final result = await GetReceiveWalletsUsecase(inner)
          .execute(onlyBitcoin: true);

      expect(result, isA<Ok<List<Wallet>, ReceiveFailure>>());
    });

    test(
      'converts a throw into a sanitized failure, raw reason logs-only',
      () async {
        final inner = _MockGetWalletsUsecase();
        when(
          () => inner.execute(
            onlyDefaults: any(named: 'onlyDefaults'),
            onlyBitcoin: any(named: 'onlyBitcoin'),
            onlyLiquid: any(named: 'onlyLiquid'),
            sync: any(named: 'sync'),
          ),
        ).thenThrow(Exception(_rawReason));

        final result = await GetReceiveWalletsUsecase(inner)
            .execute(onlyBitcoin: true);

        switch (result) {
          case Ok():
            fail('a throw must not be reported as wallets');
          case Err(:final failure):
            expect(failure, isA<ReceiveUnexpectedFailure>());
            expect(failure.logMessage, contains('app.sqlite'));
        }
      },
    );
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
