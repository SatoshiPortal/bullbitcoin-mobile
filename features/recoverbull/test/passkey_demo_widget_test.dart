import 'dart:async';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/domain/passkey_demo_operation.dart';
import 'package:bull_recoverbull/src/domain/repositories/passkey_demo_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/run_passkey_demo_usecase.dart';
import 'package:bull_recoverbull/src/ui/pages/passkey_demo_page.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final class _PendingRepository implements PasskeyDemoRepository {
  final started = Completer<void>();
  final response = Completer<Result<String, PasskeyDemoFailure>>();
  bool cancelled = false;

  @override
  Future<Result<String, PasskeyDemoFailure>> register(
    PasskeyDemoOperation operation,
  ) {
    operation.onCancel(() => cancelled = true);
    started.complete();
    return response.future;
  }

  @override
  Future<Result<String, PasskeyDemoFailure>> open(
    String accountId,
    PasskeyDemoOperation operation,
  ) => register(operation);
}

void main() {
  testWidgets('leaving the page cancels and discards a pending registration', (
    tester,
  ) async {
    final repository = _PendingRepository();
    final demo = RunPasskeyDemoUsecase(() async => true, repository);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: RecoverBullFeature.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: Scaffold(body: PasskeyDemoEntry(demo: demo)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passkey demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create demo passkey'));
    await tester.pump();
    await repository.started.future;
    await tester.pageBack();
    await tester.pump();
    expect(repository.cancelled, isTrue);
    repository.response.complete(const Ok('account'));
    await tester.pumpAndSettle();
    expect(find.text('Open demo vault'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'preference changes hide the entry and cancel a pending ceremony',
    (tester) async {
      var enabled = true;
      final repository = _PendingRepository();
      final demo = RunPasskeyDemoUsecase(() async => enabled, repository);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: RecoverBullFeature.localizationsDelegates,
          supportedLocales: RecoverBullLocalizations.supportedLocales,
          home: Scaffold(body: PasskeyDemoEntry(demo: demo)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passkey demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create demo passkey'));
      await tester.pump();
      enabled = false;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(repository.cancelled, isTrue);
      repository.response.complete(const Ok('account'));
      await tester.pump();
      expect(find.text('Open demo vault'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Passkey demo'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
