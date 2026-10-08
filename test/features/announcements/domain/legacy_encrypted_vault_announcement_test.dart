import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/announcements/data/announcement_dismissal_repository_impl.dart';
import 'package:bb_mobile/features/announcements/data/datasources/announcement_dismissal_datasource.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/dismiss_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/get_visible_announcements_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/has_legacy_encrypted_vault_to_recreate_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapFacade extends Mock implements SwapFacade {}

class _MockHasLegacyVault extends Mock
    implements HasLegacyEncryptedVaultToRecreateUsecase {}

void main() {
  late Directory directory;
  late File file;
  late _MockSwapFacade swapFacade;
  late _MockHasLegacyVault hasLegacyVault;
  final opened = <SqliteDatabase>[];

  /// Opens the app database on the same file, as a fresh app start would.
  SqliteDatabase openDatabase() {
    final database = SqliteDatabase(NativeDatabase(file));
    opened.add(database);
    return database;
  }

  AnnouncementDismissalRepositoryImpl repositoryFor(SqliteDatabase database) =>
      AnnouncementDismissalRepositoryImpl(
        datasource: AnnouncementDismissalDatasource(sqlite: database),
      );

  Future<List<Announcement>> visible(SqliteDatabase database) async {
    final result = await GetVisibleAnnouncementsUsecase(
      repositoryFor(database),
      swapFacade,
      hasLegacyEncryptedVault: hasLegacyVault,
    ).execute();
    return (result as Ok<List<Announcement>, dynamic>).value;
  }

  Future<List<AnnouncementId>> visibleIds(SqliteDatabase database) async => [
    for (final announcement in await visible(database)) announcement.id,
  ];

  setUp(() {
    directory = Directory.systemTemp.createTempSync('announcements_');
    file = File('${directory.path}/app.sqlite');
    swapFacade = _MockSwapFacade();
    hasLegacyVault = _MockHasLegacyVault();
    when(() => swapFacade.isAppUpdateRequired).thenReturn(false);
    when(() => hasLegacyVault.execute()).thenAnswer((_) async => true);
  });

  tearDown(() async {
    for (final database in opened) {
      await database.close();
    }
    opened.clear();
    directory.deleteSync(recursive: true);
  });

  test(
    'shows the notice for a legacy vault RecoverBull does not know',
    () async {
      expect(await visibleIds(openDatabase()), [
        AnnouncementId.legacyEncryptedVault,
      ]);
    },
  );

  test('hides the notice without a legacy vault to recreate', () async {
    when(() => hasLegacyVault.execute()).thenAnswer((_) async => false);

    expect(await visibleIds(openDatabase()), isEmpty);
  });

  test('keeps the notice dismissed after a restart', () async {
    final first = openDatabase();
    final announcement = (await visible(first)).single;
    expect(announcement.id, AnnouncementId.legacyEncryptedVault);
    final dismissed = await DismissAnnouncementUsecase(
      dismissalRepository: repositoryFor(first),
    ).execute(announcement);
    expect(dismissed, isA<Ok<void, dynamic>>());
    await first.close();
    opened.remove(first);

    expect(await visibleIds(openDatabase()), isEmpty);
  });
}
