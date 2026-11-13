import 'package:bull_local_data/bull_local_data.dart' show LocalData;
import 'package:bull_local_data/generated/l10n/local_data_localizations.dart';
import 'package:bull_local_data/src/domain/local_data_failure.dart';
import 'package:bull_local_data/src/domain/local_database.dart';
import 'package:bull_local_data/src/domain/local_database_repository.dart';
import 'package:bull_local_data/src/domain/usecases/reset_local_database_usecase.dart';
import 'package:bull_local_data/src/presentation/local_data_gate_cubit.dart';
import 'package:bull_local_data/src/ui/local_data_gate_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

final class _FakeRepository implements LocalDatabaseRepository {
  final List<LocalDatabase> resets = [];
  Result<void, LocalDataFailure> resetResult = const Ok(null);

  @override
  Future<Result<UnlockedDatabase, LocalDataFailure>> unlock(
    LocalDatabase database,
  ) => throw UnimplementedError();

  @override
  Future<Result<void, LocalDataFailure>> reset(LocalDatabase database) async {
    resets.add(database);
    return resetResult;
  }
}

void main() {
  late _FakeRepository repository;
  late int retries;

  setUp(() {
    repository = _FakeRepository();
    retries = 0;
  });

  Future<void> pump(WidgetTester tester, LocalDataFailure failure) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: LocalDataLocalizations.localizationsDelegates,
        supportedLocales: LocalDataLocalizations.supportedLocales,
        home: BullSupportScope(
          onContactSupport: (context, {message}) {},
          child: BlocProvider(
            create: (_) => LocalDataGateCubit(
              failure: failure,
              reset: ResetLocalDatabaseUsecase(repository),
              retry: () async => retries++,
            ),
            child: const LocalDataGateScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('a locked keystore offers a retry and no reset', (tester) async {
    await pump(tester, const LocalDataKeystoreLockedFailure());
    expect(find.text('Unlock your device'), findsOneWidget);
    expect(find.byKey(const ValueKey('local-data-reset')), findsNothing);

    await tapKey(tester, 'local-data-retry');
    expect(retries, 1);
  });

  testWidgets(
    'a reset needs the acknowledgement, then erases that database only',
    (tester) async {
      await pump(
        tester,
        const LocalDataKeyMissingFailure(LocalDatabase.payjoin),
      );
      expect(
        find.textContaining('Your wallets are not affected'),
        findsOneWidget,
      );

      await tapKey(tester, 'local-data-reset');
      // Not acknowledged: the erase button does nothing.
      await tapKey(tester, 'local-data-reset-confirm');
      expect(repository.resets, isEmpty);
      expect(
        find.byKey(const ValueKey('local-data-reset-confirm')),
        findsOneWidget,
      );

      await tapKey(tester, 'local-data-reset-acknowledge');
      await tapKey(tester, 'local-data-reset-confirm');
      expect(repository.resets, [LocalDatabase.payjoin]);
      expect(retries, 1);
    },
  );

  testWidgets('cancelling the confirmation erases nothing', (tester) async {
    await pump(tester, const LocalDataUnreadableFailure(LocalDatabase.main));
    await tapKey(tester, 'local-data-reset');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.resets, isEmpty);
    expect(retries, 0);
  });

  testWidgets('a reset that fails says so and does not restart', (
    tester,
  ) async {
    repository.resetResult = const Err(LocalDataUnexpectedFailure('keystore'));
    await pump(tester, const LocalDataKeyCorruptFailure(LocalDatabase.main));

    await tapKey(tester, 'local-data-reset');
    await tapKey(tester, 'local-data-reset-acknowledge');
    await tapKey(tester, 'local-data-reset-confirm');

    expect(
      find.byKey(const ValueKey('local-data-reset-failed')),
      findsOneWidget,
    );
    expect(retries, 0);
  });

  testWidgets('every failure shown gets a fresh screen state', (tester) async {
    FakeSecureStoragePlatform().install();
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    const paths = LocalDatabasePaths(
      main: '/tmp/m.sqlite',
      payjoin: '/tmp/p.sqlite',
      recoverbull: '/tmp/r.sqlite',
    );
    Widget app(LocalDataFailure failure) => MaterialApp(
      theme: ThemeData(extensions: testBullExtensions),
      localizationsDelegates: LocalDataLocalizations.localizationsDelegates,
      supportedLocales: LocalDataLocalizations.supportedLocales,
      home: BullSupportScope(
        onContactSupport: (context, {message}) {},
        child: LocalData.screen(
          failure: failure,
          secrets: secrets,
          paths: paths,
          onRetry: () async => retries++,
        ),
      ),
    );

    await tester.pumpWidget(app(const LocalDataKeystoreLockedFailure()));
    await tester.pumpAndSettle();
    await tapKey(tester, 'local-data-retry');
    expect(retries, 1);

    // What the shell does when the retry fails again: a new screen, for a new failure.
    await tester.pumpWidget(
      app(const LocalDataKeyMissingFailure(LocalDatabase.payjoin)),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Your wallets are not affected'),
      findsOneWidget,
    );
    await tapKey(tester, 'local-data-retry');
    expect(retries, 2);
  });
}
