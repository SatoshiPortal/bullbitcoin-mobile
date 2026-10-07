import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_recoverbull_url_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/store_recoverbull_url_usecase.dart';
import 'package:bull_recoverbull/src/public/recoverbull.dart';
import 'package:bull_recoverbull/src/presentation/recoverbull_settings_cubit.dart';
import 'package:bull_recoverbull/src/ui/screens/settings_page.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:bull_ui/testing.dart' show testBullTheme;

class _Repository extends Mock implements RecoverBullRepository {}

class _Monitoring extends Mock
    implements RecoverBullAttemptMonitoringController {}

class _Log implements LogSink {
  @override
  void fine(String message, {Object? error, StackTrace? trace}) {}

  @override
  void info(String message, {Object? error, StackTrace? trace}) {}

  @override
  void warning(String message, {Object? error, StackTrace? trace}) {}

  @override
  void error(String message, {Object? error, StackTrace? trace}) {}

  @override
  LogSink scoped(String scope) => this;
}

void main() {
  testWidgets(
    'shows the loaded server URL and restores it after cancelling edits',
    (tester) async {
      const originalUrl = 'http://current-server.onion';
      const editedUrl = 'http://unsaved-server.onion';
      final loadedUrl = Completer<Uri>();
      final repository = _Repository();
      when(repository.fetchUrl).thenAnswer((_) => loadedUrl.future);
      final cubit = RecoverBullSettingsCubit(
        log: _Log(),
        fetchUrl: FetchRecoverbullUrlUsecase(recoverBullRepository: repository),
        storeUrl: StoreRecoverbullUrlUsecase(recoverBullRepository: repository),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [testBullTheme]),
          localizationsDelegates:
              RecoverBullLocalizations.localizationsDelegates,
          supportedLocales: RecoverBullLocalizations.supportedLocales,
          home: SettingsPage(log: _Log(), cubit: cubit),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      loadedUrl.complete(Uri.parse(originalUrl));
      await tester.pumpAndSettle();

      expect(find.text(originalUrl), findsOneWidget);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        originalUrl,
      );
      await tester.enterText(find.byType(TextFormField), editedUrl);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text(originalUrl), findsOneWidget);
      expect(find.text(editedUrl), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      verifyNever(() => repository.storeUrl(Uri.parse(editedUrl)));

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        originalUrl,
      );
    },
  );

  testWidgets('cancelling monitoring disable keeps monitoring enabled', (
    tester,
  ) async {
    final repository = _Repository();
    final monitoring = _Monitoring();
    when(
      () => repository.fetchUrl(),
    ).thenAnswer((_) async => Uri.parse('http://x.onion'));
    when(() => monitoring.enabled).thenReturn(true);
    when(() => monitoring.status()).thenAnswer(
      (_) async => const RecoverBullMonitoringStatus(
        enabled: true,
        monitoredCount: 1,
        lastSuccessfulCheck: null,
      ),
    );
    final cubit = RecoverBullSettingsCubit(
      log: _Log(),
      fetchUrl: FetchRecoverbullUrlUsecase(recoverBullRepository: repository),
      storeUrl: StoreRecoverbullUrlUsecase(recoverBullRepository: repository),
      monitoring: monitoring,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [testBullTheme]),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: SettingsPage(log: _Log(), cubit: cubit),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BullSwitch));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Your monitored backups will be forgotten. Turning monitoring back on will not restore them.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => monitoring.setEnabled(false));
  });

  Future<_Repository> editUrl(WidgetTester tester, String url) async {
    final repository = _Repository();
    when(
      () => repository.fetchUrl(),
    ).thenAnswer((_) async => Uri.parse('http://current-server.onion'));
    when(() => repository.storeUrl(any())).thenAnswer((_) async {});
    final cubit = RecoverBullSettingsCubit(
      log: _Log(),
      fetchUrl: FetchRecoverbullUrlUsecase(recoverBullRepository: repository),
      storeUrl: StoreRecoverbullUrlUsecase(recoverBullRepository: repository),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [testBullTheme]),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: SettingsPage(log: _Log(), cubit: cubit),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), url);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    return repository;
  }

  setUpAll(() => registerFallbackValue(Uri()));

  for (final url in [
    'http://new-server.onion/',
    'http://new-server.onion:8080',
  ]) {
    testWidgets('accepts the key-server URL $url', (tester) async {
      final repository = await editUrl(tester, url);

      verify(() => repository.storeUrl(Uri.parse(url))).called(1);
      expect(find.text('URL must end with .onion'), findsNothing);
    });
  }

  testWidgets('rejects a key-server URL with credentials before saving', (
    tester,
  ) async {
    final repository = await editUrl(tester, 'http://user@new-server.onion');

    verifyNever(() => repository.storeUrl(any()));
    expect(find.text('URL is not valid'), findsOneWidget);
  });
}
