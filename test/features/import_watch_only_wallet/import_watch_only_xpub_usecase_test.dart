import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/reserve_bull_owned_bip48_accounts_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBitcoinDescriptorPort extends Mock
    implements BitcoinDescriptorPort {}

class _MockReserveBullOwnedBip48AccountsUsecase extends Mock
    implements ReserveBullOwnedBip48AccountsUsecase {}

class _MockDeleteWalletUsecase extends Mock implements DeleteWalletUsecase {}

class _MockWallet extends Mock implements Wallet {}

const _xpub =
    'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';

void main() {
  late _MockBitcoinDescriptorPort descriptorPort;
  late _MockReserveBullOwnedBip48AccountsUsecase reserveAccounts;
  late _MockDeleteWalletUsecase deleteWallet;
  late ImportWatchOnlyXpubUsecase usecase;
  late WatchOnlyXpubEntity entity;

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
    usecase = ImportWatchOnlyXpubUsecase(
      descriptorPort,
      reserveAccounts,
      deleteWallet,
    );
    entity =
        const WatchOnlyWalletEntity.xpub(
              extendedPublicKey: _xpub,
              canonicalXpub: _xpub,
              network: Network.bitcoinMainnet,
              scriptType: ScriptType.bip84,
              label: 'My xpub wallet',
            )
            as WatchOnlyXpubEntity;
  });

  group('ImportWatchOnlyXpubUsecase', () {
    test('maps repository failures to ImportFailedFailure', () async {
      when(
        () => descriptorPort.importDescriptor(
          descriptor: any(named: 'descriptor'),
          network: Network.bitcoinMainnet,
          label: 'My xpub wallet',
        ),
      ).thenThrow(Exception('BDK rejected the descriptor'));

      final result = await usecase.execute(watchOnlyXpub: entity);

      expect(result, isA<Err<Wallet, ImportWatchOnlyFailure>>());
      final failure = (result as Err<Wallet, ImportWatchOnlyFailure>).failure;
      expect(failure, isA<ImportFailedFailure>());
      expect(failure.logMessage, isNull);
      verifyNever(
        () => reserveAccounts.execute(
          network: entity.network,
          signers: any(named: 'signers'),
        ),
      );
    });

    test('imports the xpub through a two-path descriptor', () async {
      final wallet = _MockWallet();
      final events = <String>[];
      when(
        () => descriptorPort.importDescriptor(
          descriptor: any(named: 'descriptor'),
          network: Network.bitcoinMainnet,
          label: 'My xpub wallet',
        ),
      ).thenAnswer((_) async {
        events.add('import');
        return wallet;
      });
      when(
        () => reserveAccounts.execute(
          network: Network.bitcoinMainnet,
          signers: any(named: 'signers'),
        ),
      ).thenAnswer((_) async {
        events.add('reserve');
        return const Ok(null);
      });

      final result = await usecase.execute(watchOnlyXpub: entity);

      final descriptor =
          verify(
                () => descriptorPort.importDescriptor(
                  descriptor: captureAny(named: 'descriptor'),
                  network: Network.bitcoinMainnet,
                  label: 'My xpub wallet',
                ),
              ).captured.single
              as String;
      expect(descriptor, startsWith('wpkh('));
      expect(descriptor, contains('/<0;1>/*'));
      expect(result, isA<Ok<Wallet, ImportWatchOnlyFailure>>());
      expect(
        (result as Ok<Wallet, ImportWatchOnlyFailure>).value,
        same(wallet),
      );
      expect(events, ['import', 'reserve']);
    });

    test('preserves a fingerprint-only origin', () async {
      final wallet = _MockWallet();
      final fingerprintOnly = entity.copyWith(masterFingerprint: 'deadbeef');
      when(
        () => descriptorPort.importDescriptor(
          descriptor: any(named: 'descriptor'),
          network: Network.bitcoinMainnet,
          label: 'My xpub wallet',
        ),
      ).thenAnswer((_) async => wallet);

      final result = await usecase.execute(watchOnlyXpub: fingerprintOnly);

      final descriptor =
          verify(
                () => descriptorPort.importDescriptor(
                  descriptor: captureAny(named: 'descriptor'),
                  network: Network.bitcoinMainnet,
                  label: 'My xpub wallet',
                ),
              ).captured.single
              as String;
      expect(descriptor, contains('[deadbeef]$_xpub/<0;1>/*'));
      expect(result, isA<Ok<Wallet, ImportWatchOnlyFailure>>());
    });
  });
}
