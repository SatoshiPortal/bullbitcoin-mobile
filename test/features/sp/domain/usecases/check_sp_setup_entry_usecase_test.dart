import 'package:bb_mobile/core/wallet/domain/wallet_mutation_guard.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/check_sp_setup_entry_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../sp_fakes.dart';

class _Configs extends Mock implements SpBackendConfigRepository {}

class _Files extends Mock implements SpAccountFilesPort {}

void main() {
  late _Configs configs;
  late _Files files;
  late CheckSpSetupEntryUsecase usecase;

  setUpAll(() => registerFallbackValue(spBackendConfig()));
  setUp(() {
    configs = _Configs();
    files = _Files();
    when(
      () => configs.hasLegacyConfig(),
    ).thenAnswer((_) async => const Ok(false));
    when(() => files.hasLegacyData()).thenAnswer((_) async => const Ok(false));
    when(() => configs.fetch()).thenAnswer((_) async => Ok(spBackendConfig()));
    when(
      () => files.hasRevokedSentinel(),
    ).thenAnswer((_) async => const Ok(false));
    when(
      () => files.verifyResumeBackups(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => files.verifyAccountIdentity(any()),
    ).thenAnswer((_) async => const Err(SpRecoveryRequired()));
    when(
      () => files.verifyPendingIdentity(any()),
    ).thenAnswer((_) async => const Err(SpRecoveryRequired()));
    usecase = CheckSpSetupEntryUsecase(
      configs: configs,
      files: files,
      walletMutationGuard: WalletMutationGuard(),
    );
  });

  test('only a matching pending marker offers recovery', () async {
    when(
      () => files.verifyPendingIdentity(any()),
    ).thenAnswer((_) async => const Ok(null));
    final result = await usecase.execute();
    expect((result as Err).failure, isA<SpRecoveryRequired>());
    verifyNever(() => files.createAccountDir(any()));
  });

  test('verified marker routes to the existing account', () async {
    when(
      () => files.verifyAccountIdentity(any()),
    ).thenAnswer((_) async => const Ok(null));
    expect((await usecase.execute() as Ok).value, isTrue);
    verifyNever(() => files.verifyPendingIdentity(any()));
  });

  test(
    'missing config is fresh only when no directory or backup exists',
    () async {
      when(() => configs.fetch()).thenAnswer((_) async => const Ok(null));
      when(
        () => files.accountDirExists(),
      ).thenAnswer((_) async => const Ok(false));
      when(
        () => files.hasOrphanBackups(),
      ).thenAnswer((_) async => const Ok(false));
      expect((await usecase.execute() as Ok).value, isFalse);
      when(
        () => files.hasOrphanBackups(),
      ).thenAnswer((_) async => const Ok(true));
      expect((await usecase.execute() as Err).failure, isA<SpConfigInvalid>());
    },
  );

  test('unverifiable marker is not offered as resumable', () async {
    final result = await usecase.execute();
    expect((result as Err).failure, isA<SpConfigInvalid>());
    verifyNever(() => files.deleteAccountDir());
  });

  test('legacy and incomplete backups block without mutation', () async {
    when(
      () => configs.hasLegacyConfig(),
    ).thenAnswer((_) async => const Ok(true));
    expect(
      (await usecase.execute() as Err).failure,
      isA<SpLegacySourceUnverified>(),
    );
    when(
      () => configs.hasLegacyConfig(),
    ).thenAnswer((_) async => const Ok(false));
    when(
      () => files.verifyResumeBackups(any()),
    ).thenAnswer((_) async => const Err(SpRecoveryRequired()));
    expect((await usecase.execute() as Err).failure, isA<SpConfigInvalid>());
    verifyNever(() => files.createAccountDir(any()));
    verifyNever(() => files.deleteAccountDir());
  });
}
