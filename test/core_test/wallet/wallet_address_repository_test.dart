import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockLwkWalletDatasource extends Mock implements LwkWalletDatasource {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

const _bitcoinWalletId = '[abcdef12/84h/0h/0h]';
const _liquidWalletId = '[abcdef12/84h/1776h/0h]';

WalletMetadataModel _buildBitcoinMetadata({int lastReceiveAddressIndex = 0}) {
  return WalletMetadataModel(
    id: _bitcoinWalletId,
    masterFingerprint: 'abcdef12',
    xpubFingerprint: '12345678',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'xpub-fake',
    externalPublicDescriptor: 'wpkh([abcdef12/84h/0h/0h]xpub-fake/0/*)',
    internalPublicDescriptor: 'wpkh([abcdef12/84h/0h/0h]xpub-fake/1/*)',
    signer: Signer.local,
    isDefault: false,
    lastReceiveAddressIndex: lastReceiveAddressIndex,
  );
}

WalletMetadataModel _buildLiquidMetadata({int lastReceiveAddressIndex = 0}) {
  return WalletMetadataModel(
    id: _liquidWalletId,
    masterFingerprint: 'abcdef12',
    xpubFingerprint: '12345678',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'xpub-fake',
    externalPublicDescriptor: 'elwpkh([abcdef12/84h/1776h/0h]xpub-fake/0/*)',
    internalPublicDescriptor: 'elwpkh([abcdef12/84h/1776h/0h]xpub-fake/1/*)',
    signer: Signer.local,
    isDefault: false,
    lastReceiveAddressIndex: lastReceiveAddressIndex,
  );
}

void main() {
  late _MockWalletMetadataDatasource walletMetadataDatasource;
  late _MockBdkWalletDatasource bdkWalletDatasource;
  late _MockLwkWalletDatasource lwkWalletDatasource;
  late _MockLabelsFacade labelsFacade;
  late WalletAddressRepository repository;

  setUpAll(() {
    registerFallbackValue(_buildBitcoinMetadata());
    registerFallbackValue(WalletModel.fromMetadata(_buildBitcoinMetadata()));
  });

  setUp(() {
    walletMetadataDatasource = _MockWalletMetadataDatasource();
    bdkWalletDatasource = _MockBdkWalletDatasource();
    lwkWalletDatasource = _MockLwkWalletDatasource();
    labelsFacade = _MockLabelsFacade();

    repository = WalletAddressRepository(
      walletMetadataDatasource: walletMetadataDatasource,
      bdkWalletDatasource: bdkWalletDatasource,
      lwkWalletDatasource: lwkWalletDatasource,
      labelsFacade: labelsFacade,
    );

    when(
      () => labelsFacade.fetchByReference(any()),
    ).thenAnswer((_) async => <Label>[]);
    when(() => walletMetadataDatasource.store(any())).thenAnswer((_) async {});
  });

  group('Bitcoin wallet — lastReceiveAddressIndex persistence', () {
    test('generateNewReceiveAddress persists a higher index than the stored '
        'one', () async {
      when(() => walletMetadataDatasource.fetch(_bitcoinWalletId)).thenAnswer(
        (_) async => _buildBitcoinMetadata(lastReceiveAddressIndex: 3),
      );
      when(
        () => bdkWalletDatasource.getNewAddress(wallet: any(named: 'wallet')),
      ).thenAnswer((_) async => (index: 4, address: 'bc1qnew'));

      await repository.generateNewReceiveAddress(walletId: _bitcoinWalletId);

      final stored =
          verify(
                () => walletMetadataDatasource.store(captureAny()),
              ).captured.single
              as WalletMetadataModel;
      expect(stored.lastReceiveAddressIndex, 4);
    });

    test('getLastRevealedReceiveAddress persists a higher index than the '
        'stored one', () async {
      when(() => walletMetadataDatasource.fetch(_bitcoinWalletId)).thenAnswer(
        (_) async => _buildBitcoinMetadata(lastReceiveAddressIndex: 0),
      );
      when(
        () => bdkWalletDatasource.getLastRevealedAddressOrNew(
          wallet: any(named: 'wallet'),
        ),
      ).thenAnswer((_) async => (index: 7, address: 'bc1qrevealed'));

      await repository.getLastRevealedReceiveAddress(
        walletId: _bitcoinWalletId,
      );

      final stored =
          verify(
                () => walletMetadataDatasource.store(captureAny()),
              ).captured.single
              as WalletMetadataModel;
      expect(stored.lastReceiveAddressIndex, 7);
    });

    test('never persists a lower index than the one already stored', () async {
      when(() => walletMetadataDatasource.fetch(_bitcoinWalletId)).thenAnswer(
        (_) async => _buildBitcoinMetadata(lastReceiveAddressIndex: 10),
      );
      when(
        () => bdkWalletDatasource.getLastRevealedAddressOrNew(
          wallet: any(named: 'wallet'),
        ),
      ).thenAnswer((_) async => (index: 2, address: 'bc1qstale'));

      await repository.getLastRevealedReceiveAddress(
        walletId: _bitcoinWalletId,
      );

      verifyNever(() => walletMetadataDatasource.store(any()));
    });

    test(
      'does not persist when the revealed index equals the stored one',
      () async {
        when(() => walletMetadataDatasource.fetch(_bitcoinWalletId)).thenAnswer(
          (_) async => _buildBitcoinMetadata(lastReceiveAddressIndex: 5),
        );
        when(
          () => bdkWalletDatasource.getLastRevealedAddressOrNew(
            wallet: any(named: 'wallet'),
          ),
        ).thenAnswer((_) async => (index: 5, address: 'bc1qsame'));

        await repository.getLastRevealedReceiveAddress(
          walletId: _bitcoinWalletId,
        );

        verifyNever(() => walletMetadataDatasource.store(any()));
      },
    );
  });

  group('Liquid wallet — unchanged', () {
    test('generateNewReceiveAddress never persists wallet metadata for a '
        'Liquid wallet', () async {
      when(
        () => walletMetadataDatasource.fetch(_liquidWalletId),
      ).thenAnswer((_) async => _buildLiquidMetadata());
      when(
        () => lwkWalletDatasource.getLastUnusedAddress(
          wallet: any(named: 'wallet'),
        ),
      ).thenAnswer(
        (_) async => (
          confidential: 'lq1confidential',
          index: 0,
          standard: 'lq1standard',
        ),
      );
      when(
        () => lwkWalletDatasource.getAddressByIndex(
          any(),
          wallet: any(named: 'wallet'),
        ),
      ).thenAnswer(
        (_) async => (
          confidential: 'lq1confidentialnew',
          index: 1,
          standard: 'lq1standardnew',
        ),
      );

      await repository.generateNewReceiveAddress(walletId: _liquidWalletId);

      verifyNever(() => walletMetadataDatasource.store(any()));
    });

    test('getLastRevealedReceiveAddress never persists wallet metadata for a '
        'Liquid wallet', () async {
      when(
        () => walletMetadataDatasource.fetch(_liquidWalletId),
      ).thenAnswer((_) async => _buildLiquidMetadata());
      when(
        () => lwkWalletDatasource.getLastUnusedAddress(
          wallet: any(named: 'wallet'),
        ),
      ).thenAnswer(
        (_) async => (
          confidential: 'lq1confidential',
          index: 0,
          standard: 'lq1standard',
        ),
      );

      await repository.getLastRevealedReceiveAddress(walletId: _liquidWalletId);

      verifyNever(() => walletMetadataDatasource.store(any()));
    });
  });
}
