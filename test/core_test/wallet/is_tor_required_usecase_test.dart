import 'package:bb_mobile/features/wallet/domain/repositories/wallet_reader_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/is_tor_required_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show Wallet;
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _WalletRepository extends Mock implements WalletReaderRepository {}

class _Wallet extends Mock implements Wallet {}

void main() {
  late _WalletRepository repository;
  late IsTorRequiredUsecase usecase;

  void stubMainnetBitcoinDefaults(Result<List<Wallet>, WalletFailure> result) {
    when(repository.getDefaultMainnetBitcoinWallets)
        .thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _WalletRepository();
    usecase = IsTorRequiredUsecase(repository);
  });

  test(
    'uses the encrypted backup of the first default mainnet wallet',
    () async {
      final first = _Wallet();
      final second = _Wallet();
      when(() => first.latestEncryptedBackup).thenReturn(null);
      when(() => second.latestEncryptedBackup).thenReturn(DateTime.utc(2026));
      stubMainnetBitcoinDefaults(Ok([first, second]));

      expect((await usecase.execute() as Ok).value, isFalse);

      when(() => first.latestEncryptedBackup).thenReturn(DateTime.utc(2026));
      expect((await usecase.execute() as Ok).value, isTrue);
    },
  );

  test('propagates a wallet read failure', () async {
    const failure = WalletStorageFailure('read failed');
    stubMainnetBitcoinDefaults(const Err(failure));

    expect((await usecase.execute() as Err).failure, same(failure));
  });
}
