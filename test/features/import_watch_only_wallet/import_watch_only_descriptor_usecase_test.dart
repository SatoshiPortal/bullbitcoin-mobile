import 'package:bb_mobile/core/utils/result.dart';
import 'package:wallet/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWatchOnlyDescriptor extends Mock
    implements satoshifier.WatchOnlyDescriptor {}

class _MockDescriptor extends Mock implements satoshifier.Descriptor {}

void main() {
  late _MockWalletRepository repository;
  late ImportWatchOnlyDescriptorUsecase usecase;
  late WatchOnlyDescriptorEntity entity;
  late _MockDescriptor descriptor;

  setUpAll(() {
    registerFallbackValue(
      const WatchOnlyWalletImport(
        masterFingerprint: '73c5da0a',
        pubkeyFingerprint: 'deadbeef',
        network: Network.bitcoinMainnet,
        scriptType: ScriptType.bip84,
        signer: SignerEntity.remote,
        signerDevice: null,
        pubkey: 'key',
        externalDescriptor: 'external',
        internalDescriptor: 'internal',
        label: '',
      ),
    );
  });

  setUp(() {
    repository = _MockWalletRepository();
    usecase = ImportWatchOnlyDescriptorUsecase(walletRepository: repository);
    descriptor = _MockDescriptor();
    when(
      () => descriptor.network,
    ).thenReturn(satoshifier.Network.bitcoinMainnet);
    when(() => descriptor.derivation).thenReturn(satoshifier.Derivation.bip84);
    when(() => descriptor.pubkey).thenReturn(
      'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7',
    );
    when(() => descriptor.external).thenReturn('external-descriptor');
    when(() => descriptor.internal).thenReturn('internal-descriptor');
    final watchOnlyDescriptor = _MockWatchOnlyDescriptor();
    when(() => descriptor.fingerprint).thenReturn('73c5da0a');
    when(() => watchOnlyDescriptor.descriptor).thenReturn(descriptor);
    entity = WatchOnlyDescriptorEntity(
      watchOnlyDescriptor: watchOnlyDescriptor,
    );
  });

  test('descriptor metadata preserves identity and import defaults', () async {
    final imported = entity.copyWith(
      label: 'Cold wallet',
      signerDevice: SignerDeviceEntity.coldcardQ,
    );
    final metadata = imported.toWalletImport().toMetadata();
    expect(metadata.id, 'wpkh([73c5da0a/84h/0h/0h])');
    expect(metadata.masterFingerprint, '73c5da0a');
    expect(metadata.xpubFingerprint, '2bcd33b0');
    expect(
      metadata.xpub,
      'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7',
    );
    expect(metadata.externalPublicDescriptor, 'external-descriptor');
    expect(metadata.internalPublicDescriptor, 'internal-descriptor');
    expect(metadata.label, 'Cold wallet');
    expect(metadata.signer, SignerEntity.remote);
    expect(metadata.signerDevice, SignerDeviceEntity.coldcardQ);
    expect(metadata.isDefault, isFalse);
    expect(metadata.isPhysicalBackupTested, isFalse);
    expect(metadata.isEncryptedVaultTested, isFalse);
  });

  group('ImportWatchOnlyDescriptorUsecase', () {
    test('rejects Liquid descriptors before persistence', () async {
      when(
        () => descriptor.network,
      ).thenReturn(satoshifier.Network.liquidMainnet);

      final result = await usecase.execute(watchOnlyDescriptor: entity);

      expect(result, isA<Err<Wallet, ImportWatchOnlyFailure>>());
      expect(
        (result as Err<Wallet, ImportWatchOnlyFailure>).failure,
        isA<InvalidFormatFailure>(),
      );
      verifyNever(
        () => repository.importDescriptor(
          watchOnlyDescriptor: any(named: 'watchOnlyDescriptor'),
        ),
      );
    });

    test('maps an existing wallet to WalletAlreadyExistsFailure', () async {
      when(
        () => repository.importDescriptor(
          watchOnlyDescriptor: any(named: 'watchOnlyDescriptor'),
        ),
      ).thenThrow(const WalletAlreadyExistsException('existing-wallet-id'));

      final result = await usecase.execute(watchOnlyDescriptor: entity);

      expect(result, isA<Err<Wallet, ImportWatchOnlyFailure>>());
      expect(
        (result as Err<Wallet, ImportWatchOnlyFailure>).failure,
        isA<WalletAlreadyExistsFailure>(),
      );
    });

    test('maps a foreign repository failure to ImportFailedFailure '
        'without leaking the raw exception', () async {
      when(
        () => repository.importDescriptor(
          watchOnlyDescriptor: any(named: 'watchOnlyDescriptor'),
        ),
      ).thenThrow(Exception('BDK: descriptor checksum mismatch 0xdeadbeef'));

      final result = await usecase.execute(watchOnlyDescriptor: entity);

      expect(result, isA<Err<Wallet, ImportWatchOnlyFailure>>());
      final failure = (result as Err<Wallet, ImportWatchOnlyFailure>).failure;
      expect(failure, isA<ImportFailedFailure>());
      // The sanitized failure carries no raw reason for the UI to render.
      expect(failure.logMessage, isNull);
    });

    test('returns Ok with the wallet on success', () async {
      final wallet = _MockWallet();
      when(
        () => repository.importDescriptor(
          watchOnlyDescriptor: any(named: 'watchOnlyDescriptor'),
        ),
      ).thenAnswer((_) async => wallet);

      final result = await usecase.execute(watchOnlyDescriptor: entity);

      expect(result, isA<Ok<Wallet, ImportWatchOnlyFailure>>());
      expect(
        (result as Ok<Wallet, ImportWatchOnlyFailure>).value,
        same(wallet),
      );
      final request =
          verify(
                () => repository.importDescriptor(
                  watchOnlyDescriptor: captureAny(named: 'watchOnlyDescriptor'),
                ),
              ).captured.single
              as WatchOnlyWalletImport;
      expect(request.toMetadata(), entity.toWalletImport().toMetadata());
    });
  });
}

class _MockWallet extends Mock implements Wallet {}
