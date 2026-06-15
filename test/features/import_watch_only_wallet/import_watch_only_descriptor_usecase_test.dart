import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_error.dart';
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
      'maps a foreign repository failure to ImportWatchOnlyError.importFailed '
      'without leaking the raw exception',
      () async {
        when(
          () => repository.importDescriptor(
            watchOnlyDescriptor: entity,
          ),
        ).thenThrow(Exception('BDK: descriptor checksum mismatch 0xdeadbeef'));

        await expectLater(
          usecase.execute(watchOnlyDescriptor: entity),
          throwsA(
            isA<ImportWatchOnlyError>().having(
              (e) => e,
              'variant',
              const ImportFailedError(),
            ),
          ),
        );
      },
    );

    test('rethrows an ImportWatchOnlyError unchanged', () async {
      when(
        () => repository.importDescriptor(
          watchOnlyDescriptor: entity,
        ),
      ).thenThrow(const InvalidFormatError());

      await expectLater(
        usecase.execute(watchOnlyDescriptor: entity),
        throwsA(const InvalidFormatError()),
      );
    });

    test('returns the wallet on success', () async {
      final wallet = _MockWallet();
      when(
        () => repository.importDescriptor(
          watchOnlyDescriptor: entity,
        ),
      ).thenAnswer((_) async => wallet);

      final result = await usecase.execute(watchOnlyDescriptor: entity);

      expect(result, same(wallet));
    });
  });
}

class _MockWallet extends Mock implements Wallet {}
