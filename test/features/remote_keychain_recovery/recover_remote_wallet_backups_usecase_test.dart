import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/remote_keychain_recovery_result.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/usecases/recover_remote_wallet_backups_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/public/wallet_metadata_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late _MetadataBackupFacade metadataBackup;
  late _MetadataRecoverySession metadataSession;

  setUp(() {
    metadataBackup = _MetadataBackupFacade();
    metadataSession = _MetadataRecoverySession();
    when(
      metadataBackup.beginRecoverySession,
    ).thenAnswer((_) async => metadataSession);
    when(
      () => metadataSession.recover(
        createdWalletRefs: any(named: 'createdWalletRefs'),
      ),
    ).thenAnswer(
      (_) async => const Ok(WalletMetadataRecoveryResult.noSnapshotFound()),
    );
  });

  test(
    'recovers metadata after keychain absence using default wallet ids',
    () async {
      final calls = <String>[];
      when(metadataBackup.beginRecoverySession).thenAnswer((_) async {
        calls.add('begin');
        return metadataSession;
      });
      when(
        () => metadataSession.recover(
          createdWalletRefs: any(named: 'createdWalletRefs'),
        ),
      ).thenAnswer((invocation) async {
        calls.add('metadata');
        expect(invocation.namedArguments[#createdWalletRefs], {
          'bitcoin-default',
          'liquid-default',
        });
        return const Ok(WalletMetadataRecoveryResult.noSnapshotFound());
      });
      final usecase = RecoverRemoteWalletBackupsUsecase(() async {
        calls.add('keychain');
        return const RemoteKeychainRecoveryResult(
          status: RemoteKeychainRecoveryStatus.noBackup,
        );
      }, metadataBackup);

      final result = await usecase.execute(
        defaultCreatedWalletIds: {'bitcoin-default', 'liquid-default'},
      );

      expect(result.status, RemoteKeychainRecoveryStatus.noBackup);
      expect(calls, ['begin', 'keychain', 'metadata']);
      verify(metadataSession.close).called(1);
    },
  );

  test(
    'unions default and keychain-created wallet ids for metadata apply',
    () async {
      final usecase = RecoverRemoteWalletBackupsUsecase(
        () async => const RemoteKeychainRecoveryResult(
          status: RemoteKeychainRecoveryStatus.restored,
          createdWalletIds: ['get-paid-wallet'],
        ),
        metadataBackup,
      );

      await usecase.execute(defaultCreatedWalletIds: {'bitcoin-default'});

      final captured =
          verify(
                () => metadataSession.recover(
                  createdWalletRefs: captureAny(named: 'createdWalletRefs'),
                ),
              ).captured.single
              as Set<String>;
      expect(captured, {'bitcoin-default', 'get-paid-wallet'});
    },
  );

  test(
    'still attempts metadata recovery when keychain recovery throws',
    () async {
      final usecase = RecoverRemoteWalletBackupsUsecase(
        () async => throw StateError('keychain database unavailable'),
        metadataBackup,
      );

      await expectLater(
        usecase.execute(defaultCreatedWalletIds: {'bitcoin-default'}),
        throwsStateError,
      );

      verify(
        () => metadataSession.recover(createdWalletRefs: {'bitcoin-default'}),
      ).called(1);
      verify(metadataSession.close).called(1);
    },
  );
}

final class _MetadataBackupFacade extends Mock
    implements WalletMetadataBackupFacade {}

final class _MetadataRecoverySession extends Mock
    implements WalletMetadataRecoverySession {}
