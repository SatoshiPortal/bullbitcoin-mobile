import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/prepare_receive_address_usecase.dart';
import 'package:primitives/primitives.dart' show Ok, Err;

import 'dart:io';

import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:rust_bindings/testing.dart' show BullSdk, BullSdkApi;

import 'package:bull_logger/bull_logger.dart';
import 'package:legacy_storage/app_database.dart' show Signer;
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:labels/labels.dart';
import 'package:bb_mobile/features/address_view/domain/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/features/address_view/data/wallet_address_repository_impl.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sync/sync.dart';

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Native extends Mock implements WalletNativeLifecycle {}

class _Labels extends Mock implements Labels {}

class _Reporter extends Mock implements LoggerReporter {}

class _SdkApi extends Mock implements BullSdkApi {}

void main() {
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
      late WalletAddressRepository repository;
      final row = WalletMetadataModel(
        id: origin,
        networkCode: origin.startsWith('el')
            ? 'liquidMainnet'
            : 'bitcoinMainnet',
        masterFingerprint: 'aabbccdd',
        xpubFingerprint: 'aabbccdd',
        isEncryptedVaultTested: false,
        isPhysicalBackupTested: false,
        xpub: 'public',
        externalPublicDescriptor: origin.startsWith('el')
            ? 'ct(slip77(public),elwpkh(public))'
            : 'wpkh(public)',
        internalPublicDescriptor: origin.startsWith('el') ? '' : 'wpkh(change)',
        signer: Signer.none,
        isDefault: false,
      );
      late _Reporter reporter;
      setUp(() async {
        final directory = await Directory.systemTemp.createTemp(
          'receive-busy-',
        );
        reporter = _Reporter();
        await initializeLogging(directory: directory, reporter: reporter);
        addTearDown(() async {
          await log.flush();
          await directory.delete(recursive: true);
        });
        when(() => sdk.lwkApiTypesAddressValidate(addressString: issuedAddress))
            .thenAnswer((_) async => lwk.LiquidNetwork.mainnet);
        native = _Native();
        labels = _Labels();
        final metadata = _Metadata();
        when(() => metadata.fetch(origin)).thenAnswer((_) async => row);
        when(() => labels.fetch(reference: any(named: 'reference')))
            .thenAnswer((_) async => Ok([]));
        repository = WalletAddressRepositoryImpl(
          native: native,
          walletMetadataDatasource: metadata,
          loadWallet: (_) async => throw StateError('Unexpected address read'),
          labelsFacade: labels,
        );
      });

      test(
        'receive waits for a busy writer then returns the issued address',
        () async {
          var attempts = 0;
          when(
            () => native.receive(
              WalletCatalogPortImpl.keyFromMetadata(row),
              advance: false,
            ),
          ).thenAnswer((_) async {
            if (++attempts < 3) {
              return const Err(SyncBusyFailure());
            }
            return Ok((address: issuedAddress, index: 7));
          });
          final address = await repository.getLastRevealedReceiveAddress(
            walletId: origin,
          );
          expect(address.address, issuedAddress);
          expect(address.index, 7);
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
        when(
          () => native.receive(
            WalletCatalogPortImpl.keyFromMetadata(row),
            advance: false,
          ),
        ).thenAnswer((_) async => const Err(SyncBusyFailure()));
        final prepare = PrepareReceiveAddressUsecase(
          GetReceiveAddressUsecase(walletAddressRepository: repository),
        );
        expect(await prepare.execute(walletId: origin), isA<Err>());
        verify(
          () => native.receive(
            WalletCatalogPortImpl.keyFromMetadata(row),
            advance: false,
          ),
        ).called(5);
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
        when(
          () => native.receive(
            WalletCatalogPortImpl.keyFromMetadata(row),
            advance: false,
          ),
        ).thenAnswer((_) async => Err(error.failure));
        await expectLater(
          repository.getLastRevealedReceiveAddress(walletId: origin),
          throwsA(
            isA<WalletSnapshotException>().having(
              (e) => e.failure,
              'failure',
              isA<SyncNeedsRepairFailure>(),
            ),
          ),
        );
        verify(
          () => native.receive(
            WalletCatalogPortImpl.keyFromMetadata(row),
            advance: false,
          ),
        ).called(1);
        verifyZeroInteractions(sdk);
      });

      test('label failure after issuance never replays an advance', () async {
        when(
          () => native.receive(
            WalletCatalogPortImpl.keyFromMetadata(row),
            advance: true,
          ),
        ).thenAnswer((_) async => Ok((address: issuedAddress, index: 8)));
        const error = WalletSnapshotException(SyncBusyFailure());
        when(() => labels.fetch(reference: any(named: 'reference')))
            .thenThrow(error);
        await expectLater(
          repository.generateNewReceiveAddress(walletId: origin),
          throwsA(same(error)),
        );
        verify(
          () => native.receive(
            WalletCatalogPortImpl.keyFromMetadata(row),
            advance: true,
          ),
        ).called(1);
        if (origin.startsWith('el')) {
          verify(
            () => sdk.lwkApiTypesAddressValidate(addressString: issuedAddress),
          ).called(1);
        }
        verifyNoMoreInteractions(sdk);
      });
    });
  }
}
