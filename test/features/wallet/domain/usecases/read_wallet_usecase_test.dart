import 'package:bb_mobile/features/wallet/domain/repositories/wallet_reader_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/read_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Repository extends Mock implements WalletReaderRepository {}

void main() {
  test(
    'targeted read forwards the outcome and never enumerates wallets',
    () async {
      final repository = _Repository();
      const failure = WalletNotFoundFailure();
      when(() => repository.getWallet('A'))
          .thenAnswer((_) async => const Err(failure));
      final result = await ReadWalletUsecase(repository).execute('A');
      expect(switch (result) {
        Err(:final failure) => failure,
        Ok() => null,
      }, same(failure));
      verify(() => repository.getWallet('A')).called(1);
      verifyNoMoreInteractions(repository);
    },
  );
}
