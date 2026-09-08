import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bb_mobile/features/receive/domain/usecases/convert_receive_amount_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_address_at_index_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_currencies_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_settings_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_wallets_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/prepare_receive_address_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' hide ScriptType;

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockGetAvailableCurrenciesUsecase extends Mock
    implements GetAvailableCurrenciesUsecase {}

class _MockConvertSatsToCurrencyAmountUsecase extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

class _MockGetReceiveAddressUsecase extends Mock
    implements GetReceiveAddressUsecase {}

class _MockGetAddressAtIndexUsecase extends Mock
    implements GetAddressAtIndexUsecase {}

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
      ).thenAnswer((_) async => [_wallet()]);

      final result = await GetReceiveWalletsUsecase(
        inner,
      ).execute(onlyBitcoin: true);

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

        final result = await GetReceiveWalletsUsecase(
          inner,
        ).execute(onlyBitcoin: true);

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

  group('GetReceiveSettingsUsecase', () {
    test('converts a throw into a sanitized failure', () async {
      final inner = _MockGetSettingsUsecase();
      when(() => inner.execute()).thenThrow(Exception(_rawReason));

      final result = await GetReceiveSettingsUsecase(inner).execute();

      switch (result) {
        case Ok():
          fail('a throw must not be reported as settings');
        case Err(:final failure):
          expect(failure, isA<ReceiveUnexpectedFailure>());
          expect(failure.logMessage, contains('app.sqlite'));
      }
    });

    test('forwards the settings on success', () async {
      final inner = _MockGetSettingsUsecase();
      when(() => inner.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );

      final result = await GetReceiveSettingsUsecase(inner).execute();

      expect(result, isA<Ok<SettingsEntity, ReceiveFailure>>());
    });
  });

  group('GetReceiveCurrenciesUsecase', () {
    test('converts a throw into a sanitized failure', () async {
      final inner = _MockGetAvailableCurrenciesUsecase();
      when(() => inner.execute()).thenThrow(Exception(_rawReason));

      final result = await GetReceiveCurrenciesUsecase(inner).execute();

      switch (result) {
        case Ok():
          fail('a throw must not be reported as currencies');
        case Err(:final failure):
          expect(failure, isA<ReceiveUnexpectedFailure>());
          expect(failure.logMessage, contains('app.sqlite'));
      }
    });
  });

  group('ConvertReceiveAmountUsecase', () {
    test('converts a throw into a sanitized failure', () async {
      final inner = _MockConvertSatsToCurrencyAmountUsecase();
      when(
        () => inner.execute(
          amountSat: any(named: 'amountSat'),
          currencyCode: any(named: 'currencyCode'),
        ),
      ).thenThrow(Exception(_rawReason));

      final result = await ConvertReceiveAmountUsecase(inner).execute();

      switch (result) {
        case Ok():
          fail('a throw must not be reported as a rate');
        case Err(:final failure):
          expect(failure, isA<ReceiveUnexpectedFailure>());
          expect(failure.logMessage, contains('app.sqlite'));
      }
    });
  });

  group('PrepareReceiveAddressUsecase', () {
    test('forwards the address on success', () async {
      final inner = _MockGetReceiveAddressUsecase();
      when(
        () => inner.execute(
          walletId: any(named: 'walletId'),
          generateNew: any(named: 'generateNew'),
        ),
      ).thenAnswer((_) async => _address());

      final result = await PrepareReceiveAddressUsecase(
        inner,
      ).execute(walletId: 'w1');

      expect(result, isA<Ok<WalletAddress, ReceiveFailure>>());
    });

    test(
      'maps a throw to the dedicated address failure, not the catch-all',
      () async {
        final inner = _MockGetReceiveAddressUsecase();
        when(
          () => inner.execute(
            walletId: any(named: 'walletId'),
            generateNew: any(named: 'generateNew'),
          ),
        ).thenThrow(Exception(_rawReason));

        final result = await PrepareReceiveAddressUsecase(
          inner,
        ).execute(walletId: 'w1');

        switch (result) {
          case Ok():
            fail('a throw must not be reported as an address');
          case Err(:final failure):
            // Dedicated variant: the user gets an actionable "could not prepare
            // an address" message rather than the generic one.
            expect(failure, isA<ReceiveAddressUnavailableFailure>());
            expect(failure.logMessage, contains('app.sqlite'));
        }
      },
    );
  });

  group('GetReceiveAddressAtIndexUsecase', () {
    test('maps a throw to the dedicated address failure', () async {
      final inner = _MockGetAddressAtIndexUsecase();
      when(
        () => inner.execute(
          walletId: any(named: 'walletId'),
          index: any(named: 'index'),
        ),
      ).thenThrow(Exception(_rawReason));

      final result = await GetReceiveAddressAtIndexUsecase(
        inner,
      ).execute(walletId: 'w1', index: 1);

      switch (result) {
        case Ok():
          fail('a throw must not be reported as an address');
        case Err(:final failure):
          expect(failure, isA<ReceiveAddressUnavailableFailure>());
          expect(failure.logMessage, contains('app.sqlite'));
      }
    });
  });
}
