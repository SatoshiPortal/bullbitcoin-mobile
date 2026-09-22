import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/file_picker_wallet_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../test/features/wallet_backup/backup_codec_fixture.dart';
import '../../test/features/wallet_backup/backup_snapshot_fixture.dart';

class _Vaults extends Mock implements BullVaultFacade {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native Android save and pick preserve both backup formats and cancellation',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Native backup file fixture')),
        ),
      );
      final files = FilePickerWalletBackupRepository(FilePicker.platform);
      final codec = backupCodecFixture(_Vaults());
      final credential = BackupCredential.fromWords(backupFixtureWords);
      final snapshot = backupSnapshotFixture(credential);
      T value<T>(Result<T, WalletBackupFailure> result) => result.fold(
        (value) => value,
        (failure) => throw StateError(failure.runtimeType.toString()),
      );
      for (final format in WalletBackupFileFormat.values) {
        final source = value(
          codec.encodeFile(snapshot, credential, format: format),
        );
        debugPrint('NATIVE_FILE_SAVE_${format.name}');
        expect(value(await files.save(source, format: format)), isTrue);
        debugPrint('NATIVE_FILE_PICK_${format.name}');
        final selected = value(await files.pick());
        expect(selected == source, isTrue);
        final decoded = value(
          codec.decodeFile(selected!, credential: credential),
        );
        expect(decoded.format, format);
        expect(
          value(codec.contentHash(decoded.snapshot)),
          value(codec.contentHash(snapshot)),
        );
      }
      debugPrint('NATIVE_FILE_CANCEL_SAVE');
      expect(
        value(await files.save('{}', format: WalletBackupFileFormat.readable)),
        isFalse,
      );
      debugPrint('NATIVE_FILE_CANCEL_PICK');
      expect(value(await files.pick()), isNull);
      debugPrint('NATIVE_FILE_DONE');
    },
  );
}
