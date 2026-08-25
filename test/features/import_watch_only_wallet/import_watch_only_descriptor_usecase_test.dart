import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBitcoinDescriptorPort extends Mock
    implements BitcoinDescriptorPort {}

void main() {
  late _MockBitcoinDescriptorPort descriptorPort;
  late ImportWatchOnlyDescriptorUsecase usecase;
  late WatchOnlyDescriptorEntity entity;

  setUp(() {
    descriptorPort = _MockBitcoinDescriptorPort();
    usecase = ImportWatchOnlyDescriptorUsecase(descriptorPort);
    entity =
        WatchOnlyWalletEntity.descriptor(
              descriptor: 'wpkh(xpub/<0;1>/*)',
              network: Network.bitcoinMainnet,
              scriptType: ScriptType.bip84,
              signers: [
                WalletSigner.single(
                  masterFingerprint: '86241f88',
                  xpubFingerprint: '11111111',
                  xpub: 'xpub',
                  signer: SignerEntity.local,
                  signerDevice: null,
                ),
              ],
              label: 'Descriptor wallet',
            )
            as WatchOnlyDescriptorEntity;
  });

  group('ImportWatchOnlyDescriptorUsecase', () {
    test('maps a foreign repository failure to ImportFailedFailure '
        'without leaking the raw exception', () async {
      when(
        () => descriptorPort.importDescriptor(
          descriptor: entity.descriptor,
          network: entity.network,
          label: entity.label,
          signers: entity.signers,
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
        () => descriptorPort.importDescriptor(
          descriptor: entity.descriptor,
          network: entity.network,
          label: entity.label,
          signers: entity.signers,
        ),
      ).thenAnswer((_) async => wallet);

      final result = await usecase.execute(watchOnlyDescriptor: entity);

      expect(result, isA<Ok<Wallet, ImportWatchOnlyFailure>>());
      expect(
        (result as Ok<Wallet, ImportWatchOnlyFailure>).value,
        same(wallet),
      );
    });

    test('maps Taproot rejection to TaprootUnsupportedFailure', () async {
      when(
        () => descriptorPort.importDescriptor(
          descriptor: entity.descriptor,
          network: entity.network,
          label: entity.label,
          signers: entity.signers,
        ),
      ).thenThrow(const UnsupportedTaprootDescriptorException());

      final result = await usecase.execute(watchOnlyDescriptor: entity);

      expect(result, isA<Err<Wallet, ImportWatchOnlyFailure>>());
      final failure = (result as Err<Wallet, ImportWatchOnlyFailure>).failure;
      expect(failure, isA<TaprootUnsupportedFailure>());
      expect(failure.logMessage, isNull);
    });
  });
}

class _MockWallet extends Mock implements Wallet {}
