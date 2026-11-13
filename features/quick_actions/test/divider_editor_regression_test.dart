import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customization_test.dart' show openEditor;
import 'quick_actions_test.dart' show MemoryStorage;

void main() {
  testWidgets('every available action has a full-row delayed drag target', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openEditor(
      tester,
      QuickActionsCubit(
        storage: MemoryStorage(),
        warning: (_) {},
        exchangeVisible: Stream.value(true),
      ),
    );
    expect(
      find.byType(ReorderableDelayedDragStartListener, skipOffstage: false),
      findsNWidgets(QuickAction.values.length),
    );
    expect(
      find.descendant(
        of: find.byType(ReorderableListView),
        matching: find.byType(IconButton),
      ),
      findsNothing,
    );
  });
}
