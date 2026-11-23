import 'package:address_view/address_view.dart';
import 'package:receive/testing.dart';
import 'package:primitives/primitives.dart';

import 'dart:io';

import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:rust_bindings/testing.dart' show BullSdk, BullSdkApi;

import 'package:bull_logger/bull_logger.dart';
import 'package:labels/labels.dart';
import 'package:secrets/testing.dart' show FakeSecureStoragePlatform;
import 'package:sync/write.dart' show WalletNativeLifecycle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sync/sync.dart';

import '../../../support/inventory_fixture.dart';

class _Native extends Mock implements WalletNativeLifecycle {}

class _Labels extends Mock implements Labels {}

class _Reporter extends Mock implements LoggerReporter {}

class _SdkApi extends Mock implements BullSdkApi {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sdk = _SdkApi();
  // Liquid validation uses FRB; busy/recovery behavior does not need its FFI.
  setUpAll(() => BullSdk.initMock(api: sdk));
  tearDownAll(BullSdk.dispose);
  setUp(() => reset(sdk));
  for (final origin in [
    'wpkh([aabbccdd/84h/0h/0h])',
    'elwpkh([aabbccdd/84h/1776h/0h])',
  ]) {
    group(origin.startsWith('el') ? 'Liquid' : 'Bitcoin', () {
      final issuedAddress = origin.startsWith('el')
          ? 'lq1pqvxwxl7pckz6p4vq0dh7dv8ae3lha97w4wjqls8p508xc2jus85sf3xgkzdkm3qdgmckph0a303qvnfyxsffyszy8s2w5ev5ys93xx0we046p4uqlt24'
          : '1BoatSLRHtKNngkdXEeobR76b53LETtpyT';
      late _Native native;
      late _Labels labels;
      late AddressView repository;
      final liquid = origin.startsWith('el');
      final key = WalletKey(
        id: origin,
        network: liquid ? LiquidNetwork.mainnet : BitcoinNetwork.mainnet,
      );
      late _Reporter reporter;
      setUp(() async {
        FakeSecureStoragePlatform().install();
        final directory = await Directory.systemTemp.createTemp(
          'receive-busy-',
        );
        final fixture = await InventoryFixture.open(directory);
        await fixture.addPublicWallet(
          id: origin,
          network: liquid ? 'liquidMainnet' : 'bitcoinMainnet',
        );
        reporter = _Reporter();
        await initializeLogging(directory: directory, reporter: reporter);
        addTearDown(() async {
          await log.flush();
          await fixture.close();
          await directory.delete(recursive: true);
        });
        when(() => sdk.lwkApiTypesAddressValidate(addressString: issuedAddress))
            .thenAnswer((_) async => lwk.LiquidNetwork.mainnet);
        native = _Native();
        labels = _Labels();
        when(() => labels.fetch(reference: any(named: 'reference')))
            .thenAnswer((_) async => Ok([]));
        repository = AddressView.open(
          native: native,
          labels: labels,
          inventory: fixture.inventory,
          loadWallet: (_) async => throw StateError('Unexpected address read'),
        );
      });

      test(
        'receive waits for a busy writer then returns the issued address',
        () async {
          var attempts = 0;
          when(() => native.receive(key, advance: false)).thenAnswer((_) async {
            if (++attempts < 3) {
              return const Err(SyncBusyFailure());
            }
            return Ok((address: issuedAddress, index: 7));
          });
          final address = await repository.receiveAddress(walletId: origin);
          expect(
            address,
            isA<Ok<WalletAddress, AddressViewFailure>>()
                .having(
                  (result) => result.value.address,
                  'address',
                  issuedAddress,
                )
                .having((result) => result.value.index, 'index', 7),
          );
          expect(attempts, 3);
          if (origin.startsWith('el')) {
            verify(
              () =>
                  sdk.lwkApiTypesAddressValidate(addressString: issuedAddress),
            ).called(1);
          }
          verifyNoMoreInteractions(sdk);
          expect(
            (await log.readLogs()).map(
              (line) => line.split('\t').sublist(1, 3),
            ),
            [
              ['FINE', 'Logs created'],
              ['WARNING', 'Receive writer busy retry scheduled'],
              ['FINE', 'Receive writer recovered retries=2'],
            ],
          );
          verifyZeroInteractions(reporter);
        },
      );

      test('persistent busy is bounded', () async {
        when(() => native.receive(key, advance: false))
            .thenAnswer((_) async => const Err(SyncBusyFailure()));
        final prepare = PrepareReceiveAddressUsecase(repository);
        expect(await prepare.execute(walletId: origin), isA<Err>());
        verify(() => native.receive(key, advance: false)).called(5);
        verifyNever(() => labels.fetch(reference: any(named: 'reference')));
        verifyZeroInteractions(sdk);
        expect(
          (await log.readLogs()).map((line) => line.split('\t').sublist(1, 3)),
          [
            ['FINE', 'Logs created'],
            ['WARNING', 'Receive writer busy retry scheduled'],
            ['WARNING', 'Receive address failed reason=busy attempts=5'],
          ],
        );
        verifyZeroInteractions(reporter);
      });

      test('other failures are not retried', () async {
        const error = WalletSnapshotException(SyncNeedsRepairFailure());
        when(() => native.receive(key, advance: false))
            .thenAnswer((_) async => Err(error.failure));
        expect(
          await repository.receiveAddress(walletId: origin),
          isA<Err<WalletAddress, AddressViewFailure>>().having(
            (result) => result.failure.logMessage,
            'failure',
            error.failure.logCode,
          ),
        );
        verify(() => native.receive(key, advance: false)).called(1);
        verifyZeroInteractions(sdk);
      });

      test('label failure after issuance never replays an advance', () async {
        when(() => native.receive(key, advance: true))
            .thenAnswer((_) async => Ok((address: issuedAddress, index: 8)));
        const error = WalletSnapshotException(SyncBusyFailure());
        when(() => labels.fetch(reference: any(named: 'reference')))
            .thenThrow(error);
        expect(
          await repository.receiveAddress(walletId: origin, advance: true),
          isA<Err<WalletAddress, AddressViewFailure>>(),
        );
        verify(() => native.receive(key, advance: true)).called(1);
        if (origin.startsWith('el')) {
          verify(
            () => sdk.lwkApiTypesAddressValidate(addressString: issuedAddress),
          ).called(1);
        }
        verifyNoMoreInteractions(sdk);
      });

      test('typed label unavailability preserves the issued address', () async {
        when(() => native.receive(key, advance: true))
            .thenAnswer((_) async => Ok((address: issuedAddress, index: 9)));
        when(() => labels.fetch(reference: issuedAddress))
            .thenAnswer((_) async => const Err(LabelUnexpectedFailure()));

        final result = await repository.receiveAddress(
          walletId: origin,
          advance: true,
        );

        expect(
          result,
          isA<Ok<WalletAddress, AddressViewFailure>>()
              .having(
                (result) => result.value.address,
                'address',
                issuedAddress,
              )
              .having((result) => result.value.index, 'index', 9)
              .having((result) => result.value.labels, 'labels', isEmpty),
        );
        verify(() => native.receive(key, advance: true)).called(1);
        verify(() => labels.fetch(reference: issuedAddress)).called(1);
      });
    });
  }
}
