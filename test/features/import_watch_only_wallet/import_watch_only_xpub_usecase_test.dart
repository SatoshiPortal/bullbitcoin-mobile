import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  late _MockWalletRepository repository;
  late ImportWatchOnlyXpubUsecase usecase;
  late WatchOnlyXpubEntity entity;

  setUpAll(() {
    registerFallbackValue(Network.bitcoinMainnet);
    registerFallbackValue(ScriptType.bip84);
  });

  setUp(() {
    repository = _MockWalletRepository();
    usecase = ImportWatchOnlyXpubUsecase(walletRepository: repository);
    final extendedPubkey = satoshifier.ExtendedPubkey(
      pubkey: List<int>.filled(78, 0),
      derivation: satoshifier.Derivation.bip84,
      network: satoshifier.Network.bitcoinMainnet,
    );
    entity =
        WatchOnlyWalletEntity.xpub(
              watchOnlyXpub: satoshifier.WatchOnlyXpub(
                extendedPubkey: extendedPubkey,
              ),
              label: 'My xpub wallet',
            )
            as WatchOnlyXpubEntity;
  });

  group('ImportWatchOnlyXpubUsecase', () {
    test(
      'maps a foreign repository failure to ImportFailedFailure '
      'without leaking the raw exception',
      () async {
        when(
          () => repository.importWatchOnlyXpub(
            xpub: any(named: 'xpub'),
            network: any(named: 'network'),
            scriptType: any(named: 'scriptType'),
            label: any(named: 'label'),
          ),
        ).thenThrow(Exception('BDK: invalid xpub checksum 0xdeadbeef'));

        final result = await usecase.execute(watchOnlyXpub: entity);

        expect(result, isA<Err<Wallet, ImportWatchOnlyFailure>>());
        final failure = (result as Err<Wallet, ImportWatchOnlyFailure>).failure;
        expect(failure, isA<ImportFailedFailure>());
        // The sanitized failure carries no raw reason for the UI to render.
        expect(failure.logMessage, isNull);
      },
    );

    test('returns Ok with the wallet on success', () async {
      final wallet = _MockWallet();
      when(
        () => repository.importWatchOnlyXpub(
          xpub: any(named: 'xpub'),
          network: any(named: 'network'),
          scriptType: any(named: 'scriptType'),
          label: any(named: 'label'),
        ),
      ).thenAnswer((_) async => wallet);

      final result = await usecase.execute(watchOnlyXpub: entity);

      expect(result, isA<Ok<Wallet, ImportWatchOnlyFailure>>());
      expect((result as Ok<Wallet, ImportWatchOnlyFailure>).value, same(wallet));
    });
  });
}
