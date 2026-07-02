import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWatchOnlyDescriptor extends Mock
    implements satoshifier.WatchOnlyDescriptor {}

void main() {
  late _MockWalletRepository repository;
  late ImportWatchOnlyDescriptorUsecase usecase;
  late WatchOnlyDescriptorEntity entity;

  setUp(() {
    repository = _MockWalletRepository();
    usecase = ImportWatchOnlyDescriptorUsecase(walletRepository: repository);
    entity =
        WatchOnlyWalletEntity.descriptor(
              watchOnlyDescriptor: _MockWatchOnlyDescriptor(),
            )
            as WatchOnlyDescriptorEntity;
  });

  group('ImportWatchOnlyDescriptorUsecase', () {
    test(
      'maps a foreign repository failure to ImportFailedFailure '
      'without leaking the raw exception',
      () async {
        when(
          () => repository.importDescriptor(
            watchOnlyDescriptor: entity,
          ),
        ).thenThrow(Exception('BDK: descriptor checksum mismatch 0xdeadbeef'));

        final result = await usecase.execute(watchOnlyDescriptor: entity);

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
        () => repository.importDescriptor(
          watchOnlyDescriptor: entity,
        ),
      ).thenAnswer((_) async => wallet);

      final result = await usecase.execute(watchOnlyDescriptor: entity);

      expect(result, isA<Ok<Wallet, ImportWatchOnlyFailure>>());
      expect((result as Ok<Wallet, ImportWatchOnlyFailure>).value, same(wallet));
    });
  });
}

class _MockWallet extends Mock implements Wallet {}
