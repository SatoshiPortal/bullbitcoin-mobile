import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logs/src/domain/log_entry.dart';
import 'package:bull_logs/src/domain/repositories/logs_repository.dart';
import 'package:bull_logs/src/domain/logs_failure.dart';
import 'package:bull_logs/src/domain/usecases/delete_logs_usecase.dart';
import 'package:bull_logs/src/domain/usecases/export_logs_usecase.dart';
import 'package:bull_logs/src/domain/usecases/filter_logs_usecase.dart';
import 'package:bull_logs/src/domain/usecases/load_logs_usecase.dart';
import 'package:bull_logs/src/domain/usecases/share_logs_usecase.dart';
import 'package:bull_logs/src/presentation/logs_cubit.dart';
import 'package:bull_logs/src/presentation/logs_state.dart';
import 'package:bull_logs/src/ui/log_settings_screen.dart';
import 'package:bull_logs/src/ui/log_viewer_widget.dart';
import 'package:bull_logs/generated/l10n/logs_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:bull_ui/testing.dart';

class _Repository implements LogsRepository {
  final List<LogEntry> entries;
  List<LogEntry>? sharedEntries;

  _Repository(this.entries);

  @override
  Future<Result<List<LogEntry>, LogsFailure>> read() async => Ok(entries);

  @override
  Future<Result<void, LogsFailure>> delete() async => const Ok(null);

  @override
  Future<Result<void, LogsFailure>> share(List<LogEntry> entries) async {
    sharedEntries = entries;
    return const Ok(null);
  }

  @override
  Future<Result<bool, LogsFailure>> export(List<LogEntry> entries) async =>
      const Ok(true);
}

final class _FlakyRepository implements LogsRepository {
  int reads = 0;

  @override
  Future<Result<List<LogEntry>, LogsFailure>> read() async {
    reads++;
    return reads == 1
        ? Err(const LogsStorageFailure('first read'))
        : const Ok(<LogEntry>[]);
  }

  @override
  Future<Result<void, LogsFailure>> delete() async => const Ok(null);

  @override
  Future<Result<void, LogsFailure>> share(List<LogEntry> entries) async =>
      const Ok(null);

  @override
  Future<Result<bool, LogsFailure>> export(List<LogEntry> entries) async =>
      const Ok(true);
}

void main() {
  testWidgets('retries an initial read failure through an accessible action', (
    tester,
  ) async {
    final repository = _FlakyRepository();
    final cubit = LogsCubit(
      LoadLogsUsecase(repository),
      DeleteLogsUsecase(repository),
      ShareLogsUsecase(repository),
      ExportLogsUsecase(repository),
      const FilterLogsUsecase(),
    );
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [testBullTheme]),
        localizationsDelegates: [LogsLocalizations.delegate],
        supportedLocales: [const Locale('en')],
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const LogsViewerWidget(),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('logs-retry')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('logs-retry')));
    await tester.pumpAndSettle();
    expect(cubit.state.status, LogsStatus.ready);
    expect(repository.reads, 2);
  });

  testWidgets('keeps duplicate raw lines as separate rows', (tester) async {
    final entries = <LogEntry>[
      const LogEntry(
        rawLine: 'same',
        timestamp: null,
        rawLevel: 'INFO',
        severity: LogSeverity.info,
        displayText: 'one',
      ),
      const LogEntry(
        rawLine: 'same',
        timestamp: null,
        rawLevel: 'INFO',
        severity: LogSeverity.info,
        displayText: 'two',
      ),
    ];
    final repository = _Repository(entries);
    final cubit = LogsCubit(
      LoadLogsUsecase(repository),
      DeleteLogsUsecase(repository),
      ShareLogsUsecase(repository),
      ExportLogsUsecase(repository),
      const FilterLogsUsecase(),
    );
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [testBullTheme]),
        localizationsDelegates: [LogsLocalizations.delegate],
        supportedLocales: [const Locale('en')],
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const LogsViewerWidget(),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('log-entry-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('log-entry-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('log-entry-1')));
    await tester.pump();
    expect(find.text('two'), findsOneWidget);
  });
  testWidgets(
    'builds rows lazily, toggles wrapping, and copies on long press',
    (tester) async {
      final entries = List.generate(
        10000,
        (index) => LogEntry(
          rawLine: 'raw-$index\tINFO\tmessage-$index',
          timestamp: DateTime(2026, 1, 1),
          rawLevel: 'INFO',
          severity: LogSeverity.info,
          displayText: 'message-$index ${List.filled(20, 'details').join(' ')}',
        ),
      );
      final repository = _Repository(entries);
      final cubit = LogsCubit(
        LoadLogsUsecase(repository),
        DeleteLogsUsecase(repository),
        ShareLogsUsecase(repository),
        ExportLogsUsecase(repository),
        const FilterLogsUsecase(),
      );
      addTearDown(cubit.close);
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await cubit.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [testBullTheme]),
          localizationsDelegates: [LogsLocalizations.delegate],
          supportedLocales: [const Locale('en')],
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const LogsViewerWidget(),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('log-entry-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('log-entry-9999')), findsNothing);
      expect(find.byType(BullRefreshIndicator), findsOneWidget);

      Text firstLog() =>
          tester.widget(find.byKey(const ValueKey('log-text-0')));
      Offset firstLogPoint() =>
          tester.getTopLeft(find.byKey(const ValueKey('log-entry-0'))) +
          const Offset(8, 8);

      expect(firstLog().maxLines, 1);
      expect(firstLog().softWrap, isFalse);

      await tester.tapAt(firstLogPoint());
      await tester.pump();
      expect(firstLog().maxLines, isNull);
      expect(firstLog().softWrap, isTrue);

      await tester.tapAt(firstLogPoint());
      await tester.pump();
      expect(firstLog().maxLines, 1);
      expect(firstLog().softWrap, isFalse);

      await tester.tap(find.byKey(const ValueKey('logs-wrap-all')));
      await tester.pump();
      expect(firstLog().maxLines, isNull);
      expect(firstLog().softWrap, isTrue);

      await tester.tap(find.byKey(const ValueKey('logs-wrap-all')));
      await tester.pump();
      expect(firstLog().maxLines, 1);
      expect(firstLog().softWrap, isFalse);

      await tester.longPressAt(firstLogPoint());
      await tester.pump();
      expect(copiedText, 'raw-0\tINFO\tmessage-0');
    },
  );

  testWidgets('uses a black app bar with white foreground', (tester) async {
    final repository = _Repository(const []);
    final cubit = LogsCubit(
      LoadLogsUsecase(repository),
      DeleteLogsUsecase(repository),
      ShareLogsUsecase(repository),
      ExportLogsUsecase(repository),
      const FilterLogsUsecase(),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [testBullTheme]),
        localizationsDelegates: [LogsLocalizations.delegate],
        supportedLocales: [const Locale('en')],
        home: BlocProvider.value(
          value: cubit,
          child: const LogSettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, testBullTheme.background);
    expect(appBar.foregroundColor, testBullTheme.onSurface);
    expect((appBar.title! as Text).style?.color, testBullTheme.onSurface);
    expect(find.text('No logs yet'), findsOneWidget);
  });

  testWidgets('filters live in the bottom sheet and shares visible logs', (
    tester,
  ) async {
    final warning = LogEntry(
      rawLine: 'warning',
      timestamp: DateTime(2026, 1, 1),
      rawLevel: 'WARNING',
      severity: LogSeverity.warning,
      displayText: 'disk warning',
    );
    final info = LogEntry(
      rawLine: 'info',
      timestamp: DateTime(2026, 1, 2),
      rawLevel: 'INFO',
      severity: LogSeverity.info,
      displayText: 'network ready',
    );
    final fine = LogEntry(
      rawLine: 'fine',
      timestamp: DateTime(2026, 1, 3),
      rawLevel: 'FINE',
      severity: LogSeverity.fine,
      displayText: 'trace message',
    );
    final repository = _Repository([warning, info, fine]);
    final cubit = LogsCubit(
      LoadLogsUsecase(repository),
      DeleteLogsUsecase(repository),
      ShareLogsUsecase(repository),
      ExportLogsUsecase(repository),
      const FilterLogsUsecase(),
    );
    await cubit.load();
    addTearDown(() async {
      await cubit.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [testBullTheme]),
        localizationsDelegates: [LogsLocalizations.delegate],
        supportedLocales: [const Locale('en')],
        home: BlocProvider.value(
          value: cubit,
          child: const LogSettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('logs-search')), findsNothing);
    expect(find.byKey(const ValueKey('logs-delete')), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('logs-filter')))
          .tooltip,
      'Filter logs',
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('logs-filter'))).dx,
      greaterThan(
        tester.getCenter(find.byKey(const ValueKey('logs-delete'))).dx,
      ),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('logs-share'))).dx,
      greaterThan(
        tester.getCenter(find.byKey(const ValueKey('logs-filter'))).dx,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('logs-delete')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Delete logs'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Delete logs')).style?.color,
      testBullTheme.onSurface,
    );
    expect(
      tester
          .widget<Text>(
            find.text(
              'Are you sure you want to delete all logs? '
              'This action cannot be undone.',
            ),
          )
          .style
          ?.color,
      testBullTheme.onSurface,
    );
    Navigator.of(tester.element(find.text('Delete logs'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('logs-filter')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('logs-search')), findsOneWidget);
    expect(find.text('Filter by level'), findsNothing);
    expect(find.text('Clear filter'), findsNothing);
    expect(find.byKey(const ValueKey('log-severity-all')), findsNothing);
    expect(find.byKey(const ValueKey('log-severity-unknown')), findsNothing);
    expect(find.byKey(const ValueKey('log-severity-warning')), findsOneWidget);
    expect(find.byKey(const ValueKey('log-severity-info')), findsOneWidget);
    expect(find.byKey(const ValueKey('log-severity-fine')), findsOneWidget);
    expect(find.byKey(const ValueKey('log-severity-config')), findsNothing);
    expect(find.byKey(const ValueKey('log-severity-severe')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('logs-search'))).dy,
      greaterThan(tester.getTopLeft(find.byIcon(Icons.date_range)).dy),
    );

    await tester.tap(find.byKey(const ValueKey('log-severity-warning')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('log-severity-info')));
    await tester.pump();
    expect(cubit.state.severities, {LogSeverity.warning, LogSeverity.info});
    expect(cubit.state.visibleEntries, [warning, info]);

    await tester.enterText(
      find.byKey(const ValueKey('logs-search')),
      'network',
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(cubit.state.visibleEntries, [info]);

    Navigator.of(
      tester.element(find.byKey(const ValueKey('logs-search'))),
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logs-share')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.share_sharp));
    await tester.pumpAndSettle();

    expect(repository.sharedEntries, [info]);
  });
}
