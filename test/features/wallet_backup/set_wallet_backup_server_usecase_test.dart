import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/set_wallet_backup_server_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

final class _StateRepository extends Mock
    implements WalletBackupStateRepository {}

/// Serialization against publication belongs to the job runner now, so what is
/// left here is the origin contract itself.
void main() {
  late _StateRepository state;

  setUp(() {
    state = _StateRepository();
    when(
      () => state.setServerUrl(any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  test('stores a parsed origin', () async {
    final usecase = SetWalletBackupServerUsecase(
      state,
      parseOrigin: Uri.tryParse,
    );

    expect(
      await usecase.execute('  https://backup.example.com  '),
      isA<Ok<void, WalletBackupFailure>>(),
    );

    verify(() => state.setServerUrl('https://backup.example.com')).called(1);
  });

  test('an empty value restores the default origin', () async {
    final usecase = SetWalletBackupServerUsecase(
      state,
      parseOrigin: Uri.tryParse,
    );

    expect(await usecase.execute('   '), isA<Ok<void, WalletBackupFailure>>());

    verify(() => state.setServerUrl(null)).called(1);
  });

  test('an unparseable origin is never written', () async {
    final usecase = SetWalletBackupServerUsecase(
      state,
      parseOrigin: (_) => null,
    );

    expect(
      await usecase.execute('not-an-origin'),
      isA<Err<void, WalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<WalletBackupInvalidServerOriginFailure>(),
      ),
    );

    verifyNever(() => state.setServerUrl(any()));
  });
}
