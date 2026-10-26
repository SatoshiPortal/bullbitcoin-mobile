import '../support/ui_labels.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch, BullSnackBar;
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
  testWidgets('owns one settings cubit across rebuilds and closes it', (
    tester,
  ) async {
    final repository = _Repository();
    when(
      repository.fetchUrl,
    ).thenAnswer((_) async => Ok(Uri.parse('http://server.onion')));
    Widget app() => MaterialApp(
      builder: (context, child) => withTestUiLabels(context, child!),
      theme: ThemeData(extensions: const [testBullTheme]),
      localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
      supportedLocales: RecoverBullLocalizations.supportedLocales,
      home: SettingsPage(
        log: _Log(),
        fetchUrlUsecase: FetchRecoverbullUrlUsecase(
          recoverBullRepository: repository,
        ),
        storeUrlUsecase: StoreRecoverbullUrlUsecase(
          recoverBullRepository: repository,
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final finder = find.byWidgetPredicate(
      (widget) =>
          widget
              is BlocBuilder<
                RecoverBullSettingsCubit,
                RecoverBullSettingsState
              >,
    );
    final initial = tester
        .widget<
          BlocBuilder<RecoverBullSettingsCubit, RecoverBullSettingsState>
        >(finder)
        .bloc!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final rebuilt = tester
        .widget<
          BlocBuilder<RecoverBullSettingsCubit, RecoverBullSettingsState>
        >(finder)
        .bloc!;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(identical(rebuilt, initial), isTrue);
    expect(initial.isClosed, isTrue);
  });

  testWidgets(
    'shows the loaded server URL and restores it after cancelling edits',
    (tester) async {
      const originalUrl = 'http://current-server.onion';
      const editedUrl = 'http://unsaved-server.onion';
      final loadedUrl = Completer<Result<Uri, RecoverBullFailure>>();
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
          builder: (context, child) => withTestUiLabels(context, child!),
          theme: ThemeData(extensions: const [testBullTheme]),
          localizationsDelegates:
              RecoverBullLocalizations.localizationsDelegates,
          supportedLocales: RecoverBullLocalizations.supportedLocales,
          home: SettingsPage(log: _Log(), cubit: cubit),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      loadedUrl.complete(Ok(Uri.parse(originalUrl)));
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
    ).thenAnswer((_) async => Ok(Uri.parse('http://x.onion')));
    when(() => monitoring.enabled).thenReturn(true);
    when(() => monitoring.status()).thenAnswer(
      (_) async => const RecoverBullMonitoringStatus(
        enabled: true,
        monitoredCount: 1,
        lastSuccessfulCheck: null,
      ),
    );
    final monitoringUsecases = createRecoverBullMonitoringSettingsUsecases(
      monitoring,
      log: _Log(),
    );
    final cubit = RecoverBullSettingsCubit(
      log: _Log(),
      fetchUrl: FetchRecoverbullUrlUsecase(recoverBullRepository: repository),
      storeUrl: StoreRecoverbullUrlUsecase(recoverBullRepository: repository),
      monitoringStatus: monitoringUsecases.load,
      changeMonitoring: monitoringUsecases.change,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => withTestUiLabels(context, child!),
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
    ).thenAnswer((_) async => Ok(Uri.parse('http://current-server.onion')));
    when(
      () => repository.storeUrl(any()),
    ).thenAnswer((_) async => const Ok(null));
    final cubit = RecoverBullSettingsCubit(
      log: _Log(),
      fetchUrl: FetchRecoverbullUrlUsecase(recoverBullRepository: repository),
      storeUrl: StoreRecoverbullUrlUsecase(recoverBullRepository: repository),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => withTestUiLabels(context, child!),
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

  testWidgets('failed server reads hide the edit form and can retry', (
    tester,
  ) async {
    final repository = _Repository();
    var reads = 0;
    when(repository.fetchUrl).thenAnswer(
      (_) async => ++reads == 1
          ? const Err(RecoverBullUnexpectedFailure('private storage detail'))
          : Ok(Uri.parse('http://current-server.onion')),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => withTestUiLabels(context, child!),
        theme: ThemeData(extensions: const [testBullTheme]),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: SettingsPage(
          log: _Log(),
          fetchUrlUsecase: FetchRecoverbullUrlUsecase(
            recoverBullRepository: repository,
          ),
          storeUrlUsecase: StoreRecoverbullUrlUsecase(
            recoverBullRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('private storage detail'), findsNothing);
    expect(find.text('Edit'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('http://current-server.onion'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets(
    'unsupported monitoring is advisory and preserves the enabled preference',
    (tester) async {
      final repository = _Repository();
      final monitoring = _Monitoring();
      when(
        repository.fetchUrl,
      ).thenAnswer((_) async => Ok(Uri.parse('http://server.onion')));
      when(monitoring.status).thenAnswer(
        (_) async => const RecoverBullMonitoringStatus(
          enabled: true,
          serverUnsupported: true,
          monitoredCount: 1,
          lastSuccessfulCheck: null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => withTestUiLabels(context, child!),
          theme: ThemeData(extensions: const [testBullTheme]),
          localizationsDelegates:
              RecoverBullLocalizations.localizationsDelegates,
          supportedLocales: RecoverBullLocalizations.supportedLocales,
          home: SettingsPage(
            log: _Log(),
            monitoring: monitoring,
            fetchUrlUsecase: FetchRecoverbullUrlUsecase(
              recoverBullRepository: repository,
            ),
            storeUrlUsecase: StoreRecoverbullUrlUsecase(
              recoverBullRepository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This server does not support attempt monitoring. You can still back up and recover vaults.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<BullSwitch>(find.byType(BullSwitch)).value, isTrue);
      expect(find.text('http://server.onion'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      verifyNever(() => monitoring.setEnabled(false));
    },
  );

  testWidgets(
    'failed monitoring load is retryable without inventing a preference or losing a URL draft',
    (tester) async {
      final repository = _Repository();
      final monitoring = _Monitoring();
      when(
        repository.fetchUrl,
      ).thenAnswer((_) async => Ok(Uri.parse('http://server.onion')));
      final retry = Completer<RecoverBullMonitoringStatus>();
      var loads = 0;
      when(monitoring.status).thenAnswer((_) {
        if (++loads == 1) {
          return Future.error(Exception('private status detail'));
        }
        return retry.future;
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => withTestUiLabels(context, child!),
          theme: ThemeData(extensions: const [testBullTheme]),
          localizationsDelegates:
              RecoverBullLocalizations.localizationsDelegates,
          supportedLocales: RecoverBullLocalizations.supportedLocales,
          home: SettingsPage(
            log: _Log(),
            monitoring: monitoring,
            fetchUrlUsecase: FetchRecoverbullUrlUsecase(
              recoverBullRepository: repository,
            ),
            storeUrlUsecase: StoreRecoverbullUrlUsecase(
              recoverBullRepository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Oops! Something went wrong'), findsOneWidget);
      expect(find.text('private status detail'), findsNothing);
      expect(find.byType(BullSwitch), findsNothing);
      expect(find.text('http://server.onion'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'http://unsaved-draft.onion',
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.byType(BullSwitch), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'http://unsaved-draft.onion',
      );
      retry.complete(
        const RecoverBullMonitoringStatus(
          enabled: true,
          monitoredCount: 1,
          lastSuccessfulCheck: null,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Oops! Something went wrong'), findsNothing);
      expect(tester.widget<BullSwitch>(find.byType(BullSwitch)).value, isTrue);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'http://unsaved-draft.onion',
      );
      verifyNever(() => repository.storeUrl(any()));
      verifyNever(() => monitoring.setEnabled(any()));
    },
  );

  testWidgets(
    'failed monitoring toggle reports a safe error and keeps the previous preference',
    (tester) async {
      final repository = _Repository();
      final monitoring = _Monitoring();
      when(
        repository.fetchUrl,
      ).thenAnswer((_) async => Ok(Uri.parse('http://server.onion')));
      when(monitoring.status).thenAnswer(
        (_) async => const RecoverBullMonitoringStatus(
          enabled: false,
          monitoredCount: 0,
          lastSuccessfulCheck: null,
        ),
      );
      final changing = Completer<void>();
      when(
        () => monitoring.setEnabled(true),
      ).thenAnswer((_) => changing.future);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => withTestUiLabels(context, child!),
          theme: ThemeData(extensions: const [testBullTheme]),
          localizationsDelegates:
              RecoverBullLocalizations.localizationsDelegates,
          supportedLocales: RecoverBullLocalizations.supportedLocales,
          home: SettingsPage(
            log: _Log(),
            monitoring: monitoring,
            fetchUrlUsecase: FetchRecoverbullUrlUsecase(
              recoverBullRepository: repository,
            ),
            storeUrlUsecase: StoreRecoverbullUrlUsecase(
              recoverBullRepository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BullSwitch));
      await tester.pump();
      expect(
        tester.widget<BullSwitch>(find.byType(BullSwitch)).onChanged,
        isNull,
      );
      changing.completeError(Exception('private toggle detail'));
      await tester.pumpAndSettle();
      expect(tester.widget<BullSwitch>(find.byType(BullSwitch)).value, isFalse);
      expect(
        tester.widget<BullSwitch>(find.byType(BullSwitch)).onChanged,
        isNotNull,
      );
      expect(find.text('Oops! Something went wrong'), findsOneWidget);
      expect(find.text('private toggle detail'), findsNothing);
      expect(find.text('http://server.onion'), findsOneWidget);
      verify(() => monitoring.setEnabled(true)).called(1);
      BullSnackBar.dismiss();
      await tester.pumpAndSettle();
    },
  );

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
