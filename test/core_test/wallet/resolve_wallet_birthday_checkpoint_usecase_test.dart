import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_birthday_checkpoint_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/resolve_wallet_birthday_checkpoint_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_birthday_checkpoint_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletBirthdayCheckpointRepository extends Mock
    implements WalletBirthdayCheckpointRepository {}

void main() {
  late _MockWalletBirthdayCheckpointRepository repository;
  late ResolveWalletBirthdayCheckpointUsecase usecase;

  final fakeCheckpoint = WalletBirthdayCheckpoint(
    requestedBirthday: DateTime.utc(2026),
    blockTimestamp: DateTime.utc(2026),
    blockHeight: 900000,
    blockHash: 'a' * 64,
  );

  setUp(() {
    repository = _MockWalletBirthdayCheckpointRepository();
    usecase = ResolveWalletBirthdayCheckpointUsecase(
      walletBirthdayCheckpointRepository: repository,
    );
    when(
      () => repository.resolve(
        requestedBirthday: any(named: 'requestedBirthday'),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer((_) async => Ok(fakeCheckpoint));
  });

  test(
    'newWallet mode passes the requested birthday through unchanged',
    () async {
      final requested = DateTime.utc(2026, 3, 10, 12);

      final result = await usecase.execute(
        requestedBirthday: requested,
        isTestnet: false,
        lookupMode: WalletBirthdayLookupMode.newWallet,
      );

      expect(result, isA<Ok<WalletBirthdayCheckpoint, dynamic>>());
      verify(
        () =>
            repository.resolve(requestedBirthday: requested, isTestnet: false),
      ).called(1);
    },
  );

  test(
    'recovery mode subtracts the 48h safety margin before resolving',
    () async {
      final requested = DateTime.utc(2026, 3, 10, 12);

      final result = await usecase.execute(
        requestedBirthday: requested,
        isTestnet: false,
        lookupMode: WalletBirthdayLookupMode.recovery,
      );

      expect(result, isA<Ok<WalletBirthdayCheckpoint, dynamic>>());
      verify(
        () => repository.resolve(
          requestedBirthday: requested.subtract(const Duration(hours: 48)),
          isTestnet: false,
        ),
      ).called(1);
    },
  );

  test('a non-UTC requested birthday is normalized to UTC first', () async {
    final localRequested = DateTime.utc(2026, 3, 10, 12);

    final result = await usecase.execute(
      requestedBirthday: localRequested,
      isTestnet: true,
      lookupMode: WalletBirthdayLookupMode.newWallet,
    );

    expect(result, isA<Ok<WalletBirthdayCheckpoint, dynamic>>());
    final captured = verify(
      () => repository.resolve(
        requestedBirthday: captureAny(named: 'requestedBirthday'),
        isTestnet: true,
      ),
    ).captured;
    expect((captured.single as DateTime).isUtc, isTrue);
  });

  test('forwards isTestnet to the repository', () async {
    final result = await usecase.execute(
      requestedBirthday: DateTime.utc(2026),
      isTestnet: true,
      lookupMode: WalletBirthdayLookupMode.newWallet,
    );

    expect(result, isA<Ok<WalletBirthdayCheckpoint, dynamic>>());
    verify(
      () => repository.resolve(
        requestedBirthday: any(named: 'requestedBirthday'),
        isTestnet: true,
      ),
    ).called(1);
  });

  test('propagates a repository failure unchanged', () async {
    when(
      () => repository.resolve(
        requestedBirthday: any(named: 'requestedBirthday'),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer(
      (_) async => const Err(WalletBirthdayCheckpointLookupFailure('boom')),
    );

    final result = await usecase.execute(
      requestedBirthday: DateTime.utc(2026),
      isTestnet: false,
      lookupMode: WalletBirthdayLookupMode.newWallet,
    );

    expect(result, isA<Err<WalletBirthdayCheckpoint, dynamic>>());
  });
}
