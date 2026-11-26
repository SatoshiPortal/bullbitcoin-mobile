import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/presentation/ark_cubit.dart';
import 'package:bull_ark/src/ui/ark_snapshot_page.dart';
import 'package:bull_ui/bull_ui.dart' show BullLoader, Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_account_screen_test.dart' as account_test;
import 'ark_information_widget_test.dart' show app;
import 'ark_operations_test.dart' show account;

void main() {
  testWidgets('a busy Ark never shows an error: the page waits, then loads', (
    tester,
  ) async {
    final client = account_test.Client()
      ..snapshot = const Err(ArkWriterBusyFailure());
    final owner = account_test.controller(client);
    await tester.pumpWidget(
      app(
        ArkSnapshotPage(cubit: owner, builder: (_) => const Text('observed')),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(BullLoader), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.textContaining('busy'), findsNothing);
    // Still busy on the next try: still just loading.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byType(BullLoader), findsOneWidget);
    // Ark is free again: the page shows what it read, unprompted.
    client.snapshot = Ok(
      ArkSnapshot(
        account: account(),
        revision: 1,
        observedAt: DateTime.utc(2026),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump();
    expect(find.text('observed'), findsOneWidget);
    expect(client.calls.where((c) => c == 'read').length, greaterThan(2));
  });

  testWidgets('a lasting failure says so calmly, with one way on', (
    tester,
  ) async {
    final client = account_test.Client()
      ..snapshot = const Err(ArkStorageFailure());
    await tester.pumpWidget(
      app(
        ArkSnapshotPage(
          cubit: account_test.controller(client),
          builder: (_) => const Text('observed'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Couldn’t load Ark'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a refresh that finds Ark busy keeps the page on screen', (
    tester,
  ) async {
    final observed = ArkSnapshot(
      account: account(),
      revision: 1,
      observedAt: DateTime.utc(2026),
    );
    final client = account_test.Client()..snapshot = Ok(observed);
    final owner = account_test.controller(client);
    await tester.pumpWidget(
      app(
        ArkSnapshotPage(cubit: owner, builder: (_) => const Text('observed')),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('observed'), findsOneWidget);
    // The next refresh finds the writer lock held by a background check.
    owner.emit(
      ArkViewFailed(const ArkOperationBusyFailure(), lastObserved: observed),
    );
    await tester.pump();
    expect(find.text('observed'), findsOneWidget);
    expect(find.byType(BullLoader), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('observed'), findsOneWidget);
  });
}
