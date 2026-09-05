import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/reserve_bull_owned_bip48_accounts_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBitcoinDescriptorPort extends Mock
    implements BitcoinDescriptorPort {}

class _MockReserveBullOwnedBip48AccountsUsecase extends Mock
    implements ReserveBullOwnedBip48AccountsUsecase {}

class _MockDeleteWalletUsecase extends Mock implements DeleteWalletUsecase {}

void main() {
  late _MockBitcoinDescriptorPort descriptorPort;
  late _MockReserveBullOwnedBip48AccountsUsecase reserveAccounts;
  late _MockDeleteWalletUsecase deleteWallet;
  late ImportWatchOnlyDescriptorUsecase usecase;
  late WatchOnlyDescriptorEntity entity;

  setUp(() {
    descriptorPort = _MockBitcoinDescriptorPort();
    reserveAccounts = _MockReserveBullOwnedBip48AccountsUsecase();
    deleteWallet = _MockDeleteWalletUsecase();
    when(
      () => reserveAccounts.execute(
        network: Network.bitcoinMainnet,
        signers: any(named: 'signers'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    usecase = ImportWatchOnlyDescriptorUsecase(
      descriptorPort,
      reserveAccounts,
      deleteWallet,
    );
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
      verifyNever(
        () => reserveAccounts.execute(
          network: entity.network,
          signers: entity.signers,
        ),
      );
    });

    test('returns Ok with the wallet on success', () async {
      final wallet = _MockWallet();
      final events = <String>[];
      when(
        () => descriptorPort.importDescriptor(
          descriptor: entity.descriptor,
          network: entity.network,
          label: entity.label,
          signers: entity.signers,
        ),
      ).thenAnswer((_) async {
        events.add('import');
        return wallet;
      });
      when(
        () => reserveAccounts.execute(
          network: entity.network,
          signers: entity.signers,
        ),
      ).thenAnswer((_) async {
        events.add('reserve');
        return const Ok(null);
      });

      final result = await usecase.execute(watchOnlyDescriptor: entity);

      expect(result, isA<Ok<Wallet, ImportWatchOnlyFailure>>());
      expect(
        (result as Ok<Wallet, ImportWatchOnlyFailure>).value,
        same(wallet),
      );
      verify(
        () => reserveAccounts.execute(
          network: entity.network,
          signers: entity.signers,
        ),
      ).called(1);
      expect(events, ['import', 'reserve']);
    });
  });
}

class _MockWallet extends Mock implements Wallet {}
