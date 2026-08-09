import 'dart:io' show FileSystemException;

import 'package:bb_mobile/core/screens/local_data_recovery_screen.dart';
import 'package:bb_mobile/core/storage/database_key_unavailable_exception.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The gate in front of the only destructive action in the app that a
/// user can reach without ever having unlocked it. What is being pinned
/// here is not the layout — it is that nothing is deleted until the user
/// has said yes twice, and that the free, non-destructive option is the
/// one on offer first.
void main() {
  late List<String> actions;

  setUp(() => actions = []);

  Future<void> pumpScreen(
    WidgetTester tester, {
    Future<void> Function()? onReset,
  }) async {
    // The screen is a tall scrolling column; the default 800x600 test
    // surface leaves the reset action below the fold and taps miss it.
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      LocalDataRecoveryScreen(
        onReset:
            onReset ??
            () async {
              actions.add('reset');
            },
        onRestart: () async {
          actions.add('restart');
        },
        error: const DatabaseKeyUnavailableException('test'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('retrying does not reset anything', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(actions, ['restart']);
  });

  testWidgets('asks for confirmation before resetting', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Reset local data'));
    await tester.pumpAndSettle();

    expect(find.text('Reset local data?'), findsOneWidget);
    expect(actions, isEmpty);
  });

  testWidgets('cancelling the confirmation resets nothing', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Reset local data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(actions, isEmpty);
  });

  testWidgets('confirming resets, then restarts', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Reset local data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    // Order matters: restarting before the reset finished would re-open
    // the database we are in the middle of deleting.
    expect(actions, ['reset', 'restart']);
  });

  testWidgets('a failed reset does not restart into the same wall', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      onReset: () async => throw const FileSystemException('file is locked'),
    );

    await tester.tap(find.text('Reset local data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(actions, isEmpty);
    expect(find.text('Could not reset local data'), findsOneWidget);

    // The snackbar holds a static auto-dismiss timer that outlives the
    // widget tree; leaving it pending fails the test's own invariants.
    SnackBarUtils.dismiss();
    await tester.pumpAndSettle();
  });
}
