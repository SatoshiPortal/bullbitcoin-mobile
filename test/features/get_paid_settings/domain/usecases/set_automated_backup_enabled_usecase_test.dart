import 'package:bb_mobile/features/get_paid_settings/domain/usecases/set_automated_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late _KeychainManifestFacade keychainManifest;
  late SetAutomatedBackupEnabledUsecase usecase;

  setUp(() {
    keychainManifest = _KeychainManifestFacade();
    usecase = SetAutomatedBackupEnabledUsecase(keychainManifest);
    when(
      () => keychainManifest.setBackupEnabled(any()),
    ).thenAnswer((_) async {});
    when(keychainManifest.backupNow).thenAnswer((_) async {});
  });

  test('uploads immediately after enabling', () async {
    await usecase.execute(true);

    verify(() => keychainManifest.setBackupEnabled(true)).called(1);
    verify(keychainManifest.backupNow).called(1);
  });

  test('does not upload after disabling', () async {
    await usecase.execute(false);

    verify(() => keychainManifest.setBackupEnabled(false)).called(1);
    verifyNever(keychainManifest.backupNow);
  });

  test('keeps activation successful when initial upload fails', () async {
    when(keychainManifest.backupNow).thenThrow(Exception('offline'));

    await expectLater(usecase.execute(true), completes);

    verify(() => keychainManifest.setBackupEnabled(true)).called(1);
  });
}

final class _KeychainManifestFacade extends Mock
    implements KeychainManifestFacade {}
