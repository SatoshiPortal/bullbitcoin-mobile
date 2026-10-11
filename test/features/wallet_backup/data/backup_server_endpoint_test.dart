import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/backup_server_http_transport.dart';
import '../backup_codec_fixture.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_backup_remote_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../backup_snapshot_fixture.dart';

class _Vaults extends Mock implements BullVaultFacade {}

T _value<T>(Result<T, WalletBackupFailure> result) =>
    (result as Ok<T, WalletBackupFailure>).value;

void main() {
  const origin = String.fromEnvironment('BULL_BACKUP_TEST_ORIGIN');
  test(
    'isolated BULL endpoint accepts authenticated lifecycle and encrypted snapshot readback',
    () async {
      final uri = Uri.parse(origin);
      expect(
        {'127.0.0.1', 'localhost', '::1'}.contains(uri.host),
        isTrue,
        reason: 'This fixture must never target a deployed service',
      );
      // A direct local backend needs the header normally supplied by its proxy.
      // This is test configuration; the production client does not send it.
      final dio = Dio(BaseOptions(headers: {'X-Real-IP': '127.0.0.1'}));
      addTearDown(() => dio.close(force: true));
      final repository = WalletBackupRemoteRepositoryImpl(
        BackupServerHttpTransport(dio: dio, origin: uri),
      );
      final credential = BackupCredential.fromWords(backupFixtureWords);
      final codec = backupCodecFixture(_Vaults());
      final snapshot = backupSnapshotFixture(credential);
      final ciphertext = _value(codec.encrypt(snapshot, credential));
      final initial = _value(await repository.fetch(credential));
      expect(
        initial.generation,
        0,
        reason: 'Run against a new isolated fixture database',
      );
      final receipt = _value(
        await repository.store(
          credential,
          ciphertext,
          generation: 1,
          expectedEtag: null,
        ),
      );
      expect(receipt, isA<WalletBackupCheckpoint>());
      final live = _value(await repository.fetch(credential));
      expect(live.etag, receipt.etag);
      expect(
        _value(
          codec.contentHash(
            _value(codec.decrypt(live.ciphertext!, credential)),
          ),
        ),
        _value(codec.contentHash(snapshot)),
      );
      expect(
        await repository.store(
          credential,
          ciphertext,
          generation: 1,
          expectedEtag: null,
        ),
        isA<Ok>(),
      );
      expect(
        (await repository.store(
                  credential,
                  ciphertext,
                  generation: 2,
                  expectedEtag: '0' * 64,
                )
                as Err)
            .failure,
        isA<WalletBackupConflictFailure>(),
      );
      final deleted = _value(
        await repository.delete(
          credential,
          generation: 2,
          expectedEtag: receipt.etag,
        ),
      );
      final tombstone = _value(await repository.fetch(credential));
      expect(tombstone, isA<WalletBackupRemoteHead>());
      expect(tombstone.found, isFalse);
      expect(tombstone.etag, deleted.etag);
      expect(tombstone.updatedAt, isNotNull);
      expect(
        await repository.delete(
          credential,
          generation: 2,
          expectedEtag: receipt.etag,
        ),
        isA<Ok>(),
      );
      final replacement = _value(
        await repository.store(
          credential,
          ciphertext,
          generation: 3,
          expectedEtag: tombstone.etag,
        ),
      );
      expect(
        await repository.delete(
          credential,
          generation: 4,
          expectedEtag: replacement.etag,
        ),
        isA<Ok>(),
      );
    },
    skip: origin.isEmpty
        ? 'Requires an isolated loopback BULL fixture (--dart-define=BULL_BACKUP_TEST_ORIGIN=...)'
        : false,
  );
}
