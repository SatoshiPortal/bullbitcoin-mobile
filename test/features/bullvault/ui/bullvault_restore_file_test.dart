import 'dart:convert';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_metadata_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_record_mapper.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/pick_bullvault_recovery_file_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_restore_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../bullvault_test_fixture.dart';

class _Restore extends Mock implements RestoreBullVaultUsecase {}

class _Picker extends FilePicker {
  FilePickerResult? result;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => result;
}

void main() {
  testWidgets(
    'recovery uses a streamed file without a local path; cancel does not restore',
    (tester) async {
      const source = '{"kind":"synthetic recovery input"}';
      final bytes = utf8.encode(source);
      final picker = _Picker()
        ..result = FilePickerResult([
          PlatformFile(
            name: 'vault.json',
            size: bytes.length,
            readStream: Stream.value(bytes),
          ),
        ]);
      FilePicker.platform = picker;
      final database = SqliteDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final codec = testBullVaultRecoveryPackageCodec();
      final pick = PickBullVaultRecoveryFileUsecase(
        BullVaultRepositoryImpl(
          BullVaultMetadataDatasource(database),
          BullVaultRecordMapper(codec),
          codec,
          filePicker: picker,
        ),
      );
      final restore = _Restore();
      when(
        () => restore.execute(
          kind: BullVaultRestoreInputKind.recoveryPackage,
          source: source,
          label: 'BullVault',
        ),
      ).thenAnswer((_) async => const Err(BullVaultInvalidRecoveryFailure()));
      final cubit = BullVaultRestoreCubit(restore, pick);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: const Scaffold(body: BullVaultRestoreScreen()),
          ),
        ),
      );
      await tester.tap(find.text('Choose recovery package'));
      await tester.pumpAndSettle();
      verify(
        () => restore.execute(
          kind: BullVaultRestoreInputKind.recoveryPackage,
          source: source,
          label: 'BullVault',
        ),
      ).called(1);
      await tester.pump(const Duration(seconds: 4));
      picker.result = null;
      await tester.tap(find.text('Choose recovery package'));
      await tester.pumpAndSettle();
      verifyNoMoreInteractions(restore);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
