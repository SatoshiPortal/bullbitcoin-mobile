import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_recovery/public/keychain_recovery_facade.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/recover_remote_keychain_manifest_usecase.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/remote_keychain_recovery_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late _ManifestFacade manifest;
  late _RecoveryFacade recovery;
  late RecoverRemoteKeychainManifestUsecase usecase;

  setUp(() {
    manifest = _ManifestFacade();
    recovery = _RecoveryFacade();
    usecase = RecoverRemoteKeychainManifestUsecase(
      manifest: manifest,
      recovery: recovery,
    );
  });

  test(
    'absence completes recovery without attempting wallet restore',
    () async {
      when(manifest.fetchRemoteImportPlan).thenAnswer(
        (_) async => const KeychainManifestRemoteImportResult.absent(),
      );

      final result = await usecase.execute();

      expect(result.status, RemoteKeychainRecoveryStatus.noBackup);
      verifyNoMoreInteractions(recovery);
    },
  );

  test('modeled service failures remain non-fatal outcomes', () async {
    when(manifest.fetchRemoteImportPlan).thenAnswer(
      (_) async => const KeychainManifestRemoteImportResult.unavailable(),
    );

    final result = await usecase.execute();

    expect(result.status, RemoteKeychainRecoveryStatus.unavailable);
  });

  test('unexpected local failures are not mislabeled as service outages', () {
    when(manifest.fetchRemoteImportPlan).thenThrow(StateError('database'));

    expect(usecase.execute(), throwsStateError);
  });
}

final class _ManifestFacade extends Mock implements KeychainManifestFacade {}

final class _RecoveryFacade extends Mock implements KeychainRecoveryFacade {}
