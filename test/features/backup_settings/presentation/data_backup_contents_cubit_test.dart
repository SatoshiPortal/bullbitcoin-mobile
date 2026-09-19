import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_data_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_data_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_contents_cubit.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../wallet_backup/backup_snapshot_fixture.dart';

class _Local extends Mock implements LoadLocalDataBackupUsecase {}

class _Server extends Mock implements InspectDataBackupUsecase {}

void main() {
  final snapshot = backupSnapshotFixture(
    BackupCredential.fromWords(backupFixtureWords),
  );
  final absent = WalletBackupInspection(
    identity: 'a' * 64,
    head: WalletBackupRemoteHead(generation: 0, etag: null),
    snapshot: null,
  );
  late _Local local;
  late _Server server;
  late DataBackupContentsCubit cubit;
  setUp(() {
    local = _Local();
    server = _Server();
    when(local.execute).thenAnswer((_) async => Ok(snapshot));
    when(server.execute).thenAnswer((_) async => Ok(absent));
    cubit = DataBackupContentsCubit(local, server);
  });
  tearDown(() => cubit.close());
  test(
    'local inspection does not fetch the server; an explicit server selection reads once',
    () async {
      await cubit.load(server: false);
      expect(cubit.state.snapshot, same(snapshot));
      expect(cubit.state.server, isFalse);
      verifyZeroInteractions(server);
      await cubit.load(server: true);
      expect(cubit.state.snapshot, isNull);
      expect(cubit.state.inspection, same(absent));
      expect(cubit.state.server, isTrue);
      verify(server.execute).called(1);
    },
  );
  test(
    'switching copies ignores the late reply and clears old contents while loading',
    () async {
      final pending =
          Completer<Result<WalletBackupInspection, BackupSettingsFailure>>();
      when(server.execute).thenAnswer((_) => pending.future);
      await cubit.load(server: false);
      final fetching = cubit.load(server: true);
      expect(cubit.state.snapshot, isNull);
      expect(cubit.state.loading, isTrue);
      await cubit.load(server: false);
      pending.complete(Ok(absent));
      await fetching;
      expect(cubit.state.server, isFalse);
      expect(cubit.state.snapshot, same(snapshot));
      expect(cubit.state.inspection, isNull);
    },
  );
  test(
    'a failed fetch is not an absent backup and explicit retry can succeed',
    () async {
      when(
        server.execute,
      ).thenAnswer((_) async => const Err(BackupSettingsUnexpectedFailure()));
      await cubit.load(server: true);
      expect(cubit.state.inspection, isNull);
      expect(cubit.state.failure, isNotNull);
      when(server.execute).thenAnswer((_) async => Ok(absent));
      await cubit.load(server: true);
      expect(cubit.state.inspection, same(absent));
      expect(cubit.state.failure, isNull);
    },
  );
}
