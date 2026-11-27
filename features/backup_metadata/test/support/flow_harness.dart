import 'dart:io';
import 'dart:typed_data';

import 'package:backup_metadata/backup_metadata_ui.dart';
import 'package:backup_metadata/src/domain/usecases/apply_restore_usecase.dart';
import 'package:backup_metadata/src/domain/usecases/configure_backup_usecase.dart';
import 'package:backup_metadata/src/domain/usecases/discover_backups_usecase.dart';
import 'package:backup_metadata/src/domain/usecases/get_backup_status_usecase.dart';
import 'package:backup_metadata/src/domain/usecases/preview_restore_usecase.dart';
import 'package:backup_metadata/src/domain/usecases/run_backup_usecase.dart';
import 'package:backup_metadata/src/presentation/backup_metadata_restore_cubit.dart';
import 'package:backup_metadata/src/presentation/backup_metadata_settings_cubit.dart';
import 'package:backup_metadata/src/ui/backup_metadata_flow.dart';
import 'package:backup_storage/backup_storage.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show Brightness, MaterialApp, Size, ThemeData;

import 'round_trip_support.dart';

Future<void> loadTestFonts() async {
  final font = [
    File('assets/fonts/GolosText.ttf'),
    File('../../assets/fonts/GolosText.ttf'),
  ].firstWhere((file) => file.existsSync());
  await (FontLoader(
    BullTypography.fontFamily,
  )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

/// Mounts the journey over a real engine: its repository, its Secrets port
/// and its labels.
Future<void> pumpFlowOver(WidgetTester tester, Engine engine) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final type = BullTypography.standard.resolved(testBullTheme.text);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        backupMetadataLocalizationsDelegate,
        ...bullUiLocalizationsDelegates,
      ],
      theme: ThemeData(
        fontFamily: BullTypography.fontFamily,
        textTheme: type.toTextTheme(),
        extensions: bullUiExtensions(
          colors: testBullTheme,
          brightness: Brightness.light,
          typography: type,
        ),
      ),
      home: BackupMetadataFlow(
        settings: BackupMetadataSettingsCubit(
          GetBackupStatusUsecase(engine.repository),
          ConfigureBackupUsecase(engine.repository),
          RunBackupUsecase(engine.repository),
        ),
        restore: BackupMetadataRestoreCubit(
          DiscoverBackupsUsecase(engine.repository),
          PreviewRestoreUsecase(engine.labelsPort),
          ApplyRestoreUsecase(engine.labelsPort, engine.secretsPort),
        ),
        destinations: const [BackupDestination.googleDrive],
        onClose: () {},
      ),
    ),
  );
  await tester.pump();
}
