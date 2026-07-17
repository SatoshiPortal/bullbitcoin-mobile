import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

// Liquid mainnet origin (network path 1776h) → PublicLwkWalletModel.
const _liquidWalletId = '[abcd1234/84h/1776h/0h]';
// Bitcoin mainnet origin (network path 0h) → PublicBdkWalletModel.
const _bitcoinWalletId = '[abcd1234/84h/0h/0h]';
const _secret5 =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _secret6 =
    '2222222222222222222222222222222222222222222222222222222222222222';

WalletMetadataModel _metadata(String id) {
  return WalletMetadataModel(
    id: id,
    masterFingerprint: 'fingerprint',
    xpubFingerprint: 'xpub-fingerprint',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'xpub',
    externalPublicDescriptor: 'external-desc',
    internalPublicDescriptor: 'internal-desc',
    signer: Signer.local,
    isDefault: true,
  );
}

Label _systemLabel(String address) =>
    Label.addr(id: 1, address: address, label: LabelSystem.swaps.label);

void main() {
  late _MockWalletMetadataDatasource metadata;
  late _MockLwkWalletDatasource lwk;
  late _MockLabelsFacade labels;
  late WalletAddressRepository repository;

  setUpAll(() {
    registerFallbackValue(
      const WalletModel.publicLwk(
        id: _liquidWalletId,
        combinedCtDescriptor: 'ct',
        isTestnet: false,
      ),
    );
  });

  setUp(() {
    metadata = _MockWalletMetadataDatasource();
    lwk = _MockLwkWalletDatasource();
    labels = _MockLabelsFacade();
    repository = WalletAddressRepository(
      walletMetadataDatasource: metadata,
      bdkWalletDatasource: _MockBdkWalletDatasource(),
      lwkWalletDatasource: lwk,
      labelsFacade: labels,
    );
  });

  group('generateNewLiquidReceiveAddressWithBlindingSecret', () {
    test(
      'returns the fresh next-index address + its blinding secret',
      () async {
        when(
          () => metadata.fetch(_liquidWalletId),
        ).thenAnswer((_) async => _metadata(_liquidWalletId));
        when(
          () => lwk.getLastUnusedAddress(wallet: any(named: 'wallet')),
        ).thenAnswer(
          (_) async => (index: 4, standard: 'std4', confidential: 'conf4'),
        );
        when(
          () => lwk.getAddressWithBlindingSecretByIndex(
            5,
            wallet: any(named: 'wallet'),
          ),
        ).thenAnswer(
          (_) async => (
            index: 5,
            standard: 'std5',
            confidential: 'lq1qfresh5',
            blindingSecret: _secret5,
          ),
        );
        when(() => labels.fetchByReference(any())).thenAnswer((_) async => []);

        final result = await repository
            .generateNewLiquidReceiveAddressWithBlindingSecret(
              walletId: _liquidWalletId,
            );

        expect(result.address, 'lq1qfresh5');
        expect(result.blindingSecretHex, _secret5);
      },
    );

    test('skips a system-labelled index and advances to a clean one', () async {
      when(
        () => metadata.fetch(_liquidWalletId),
      ).thenAnswer((_) async => _metadata(_liquidWalletId));
      when(
        () => lwk.getLastUnusedAddress(wallet: any(named: 'wallet')),
      ).thenAnswer(
        (_) async => (index: 4, standard: 'std4', confidential: 'conf4'),
      );
      when(
        () => lwk.getAddressWithBlindingSecretByIndex(
          5,
          wallet: any(named: 'wallet'),
        ),
      ).thenAnswer(
        (_) async => (
          index: 5,
          standard: 'std5',
          confidential: 'lq1qsystem5',
          blindingSecret: _secret5,
        ),
      );
      when(
        () => lwk.getAddressWithBlindingSecretByIndex(
          6,
          wallet: any(named: 'wallet'),
        ),
      ).thenAnswer(
        (_) async => (
          index: 6,
          standard: 'std6',
          confidential: 'lq1qclean6',
          blindingSecret: _secret6,
        ),
      );
      when(
        () => labels.fetchByReference('lq1qsystem5'),
      ).thenAnswer((_) async => [_systemLabel('lq1qsystem5')]);
      when(
        () => labels.fetchByReference('lq1qclean6'),
      ).thenAnswer((_) async => []);

      final result = await repository
          .generateNewLiquidReceiveAddressWithBlindingSecret(
            walletId: _liquidWalletId,
          );

      expect(result.address, 'lq1qclean6');
      expect(result.blindingSecretHex, _secret6);
    });

    test('rejects malformed secret material from the SDK', () async {
      when(
        () => metadata.fetch(_liquidWalletId),
      ).thenAnswer((_) async => _metadata(_liquidWalletId));
      when(
        () => lwk.getLastUnusedAddress(wallet: any(named: 'wallet')),
      ).thenAnswer(
        (_) async => (index: 4, standard: 'std4', confidential: 'conf4'),
      );
      when(
        () => lwk.getAddressWithBlindingSecretByIndex(
          5,
          wallet: any(named: 'wallet'),
        ),
      ).thenAnswer(
        (_) async => (
          index: 5,
          standard: 'std5',
          confidential: 'lq1qfresh5',
          blindingSecret: 'not-a-secret-key',
        ),
      );
      when(() => labels.fetchByReference(any())).thenAnswer((_) async => []);

      await expectLater(
        repository.generateNewLiquidReceiveAddressWithBlindingSecret(
          walletId: _liquidWalletId,
        ),
        throwsA(isA<WalletError>()),
      );
    });

    test(
      'refuses a Bitcoin (BDK) wallet before touching the datasource',
      () async {
        when(
          () => metadata.fetch(_bitcoinWalletId),
        ).thenAnswer((_) async => _metadata(_bitcoinWalletId));

        await expectLater(
          repository.generateNewLiquidReceiveAddressWithBlindingSecret(
            walletId: _bitcoinWalletId,
          ),
          throwsA(isA<WalletError>()),
        );
        verifyNever(
          () => lwk.getAddressWithBlindingSecretByIndex(
            any(),
            wallet: any(named: 'wallet'),
          ),
        );
      },
    );

    test('throws when the wallet is unknown', () async {
      when(() => metadata.fetch(any())).thenAnswer((_) async => null);
      await expectLater(
        repository.generateNewLiquidReceiveAddressWithBlindingSecret(
          walletId: 'missing',
        ),
        throwsA(isA<WalletError>()),
      );
    });
  });
}
