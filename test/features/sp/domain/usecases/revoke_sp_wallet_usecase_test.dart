import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/revoke_sp_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_fakes.dart';
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';

class MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

// The revoke sequence lives here, not behind one repository call, because the
// order is what makes it safe: sentinel before dispose, backups before the
// account dir, and a sentinel put back when the delete only half succeeded.
// Each individual file operation is covered by SpAccountFilesRepository's test.
void main() {
  late MockSpAccountRepository accountRepo;
  late MockSpBackendConfigRepository configRepo;
  late RevokeSpWalletUsecase usecase;

  setUp(() {
    accountRepo = MockSpAccountRepository();
    configRepo = MockSpBackendConfigRepository();
    when(() => accountRepo.beginTeardown()).thenReturn(null);
    when(() => accountRepo.endTeardown()).thenReturn(null);
    when(() => accountRepo.notifySetupChanged()).thenReturn(null);
    when(() => accountRepo.hasSession).thenReturn(true);
    when(() => accountRepo.dispose()).thenAnswer((_) async => const Ok(null));
    when(
      () => accountRepo.accountDirExists(),
    ).thenAnswer((_) async => const Ok(true));
    when(
      () => accountRepo.writeRevokedSentinel(
        skipIfPresent: any(named: 'skipIfPresent'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => accountRepo.deleteOrphanBackups(),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => accountRepo.deleteAccountDir(),
    ).thenAnswer((_) async => const Ok(null));
    when(() => configRepo.setIsSetUpNow(isSetUp: false)).thenReturn(null);
    when(() => configRepo.delete()).thenAnswer((_) async => const Ok(null));
    usecase = RevokeSpWalletUsecase(
      repository: accountRepo,
      files: accountRepo,
      configRepository: configRepo,
      guard: SpSessionGuard(),
    );
  });

  group('RevokeSpWalletUsecase ordering', () {
    test('writes the sentinel BEFORE disposing the live session', () async {
      await usecase.execute();

      verifyInOrder([
        () => accountRepo.beginTeardown(),
        () => accountRepo.writeRevokedSentinel(),
        () => accountRepo.dispose(),
      ]);
    });

    test('sweeps the backups BEFORE deleting the account dir', () async {
      // The other order would strand a backup with no sentinel anywhere, which
      // the next session establish would adopt as a live wallet.
      await usecase.execute();

      verifyInOrder([
        () => accountRepo.deleteOrphanBackups(),
        () => accountRepo.deleteAccountDir(),
      ]);
    });

    test('revokes on disk, drops the config, then notifies, all bracketed by '
        'begin/endTeardown', () async {
      await usecase.execute();

      verifyInOrder([
        () => accountRepo.beginTeardown(),
        () => accountRepo.deleteAccountDir(),
        () => configRepo.delete(),
        () => accountRepo.notifySetupChanged(),
        () => accountRepo.endTeardown(),
      ]);
    });

    test(
      'no sentinel is written when there is no account dir to mark',
      () async {
        when(
          () => accountRepo.accountDirExists(),
        ).thenAnswer((_) async => const Ok(false));

        expect(await usecase.execute(), isA<Ok<void, SpFailure>>());

        verifyNever(() => accountRepo.writeRevokedSentinel());
      },
    );

    test('a live session is not disposed when there is none', () async {
      when(() => accountRepo.hasSession).thenReturn(false);

      await usecase.execute();

      verifyNever(() => accountRepo.dispose());
    });
  });

  group('RevokeSpWalletUsecase failure paths', () {
    test('a dispose timeout does NOT abort the revoke', () async {
      // Aborting would leave a wallet that can never be deleted.
      when(
        () => accountRepo.dispose(),
      ).thenAnswer((_) async => const Err(SpSessionBusy('still locked')));

      expect(await usecase.execute(), isA<Ok<void, SpFailure>>());

      verify(() => accountRepo.deleteAccountDir()).called(1);
      verify(() => accountRepo.notifySetupChanged()).called(1);
    });

    test('a sentinel write failure stops before anything is deleted', () async {
      when(
        () => accountRepo.writeRevokedSentinel(),
      ).thenAnswer((_) async => const Err(SpUnexpected('read-only fs')));

      expect(await usecase.execute(), isA<Err<void, SpFailure>>());

      verifyNever(() => accountRepo.deleteAccountDir());
      verifyNever(() => configRepo.delete());
      verify(() => accountRepo.endTeardown()).called(1);
    });

    test('on a delete failure the sentinel is put back, SpSetupChanged is '
        'emitted, and the failure is returned', () async {
      when(
        () => accountRepo.deleteAccountDir(),
      ).thenAnswer((_) async => const Err(SpUnexpected('locked child')));

      final result = await usecase.execute();

      expect(
        result,
        isA<Err<void, SpFailure>>(),
        reason: 'a delete failure must be reported, not swallowed',
      );
      // The delete may have removed the sentinel before failing on a locked
      // child, so it goes back on disk and the SP card is dropped.
      verify(
        () => accountRepo.writeRevokedSentinel(skipIfPresent: true),
      ).called(1);
      verify(() => accountRepo.notifySetupChanged()).called(1);
      verifyNever(() => configRepo.delete());
      verify(() => accountRepo.endTeardown()).called(1);
    });

    test(
      'a config delete failure does not abort the revoke; it still notifies',
      () async {
        when(
          () => configRepo.delete(),
        ).thenAnswer((_) async => const Err(SpUnexpected('config gone')));

        await usecase.execute();

        verify(() => accountRepo.notifySetupChanged()).called(1);
        verify(() => accountRepo.endTeardown()).called(1);
      },
    );

    test(
      'a throw anywhere still runs endTeardown and comes back as Err',
      () async {
        when(
          () => accountRepo.deleteAccountDir(),
        ).thenThrow(Exception('delete boom'));

        final result = await usecase.execute();

        expect(result, isA<Err<void, SpFailure>>());
        verifyNever(() => configRepo.delete());
        verify(() => accountRepo.endTeardown()).called(1);
      },
    );
  });
}
