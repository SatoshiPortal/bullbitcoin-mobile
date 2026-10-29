import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('unselected radio is hollow, enabled and becomes selected', (
    tester,
  ) async {
    var selected = 'server';
    await tester.pumpWidget(
      wrapWithTheme(
        StatefulBuilder(
          builder: (context, setState) => BullSelectableList(
            selectedValue: selected,
            onChanged: (value) => setState(() => selected = value),
            items: const [
              BullSelectableListItem(
                title: 'Server',
                subtitle1: '',
                subtitle2: '',
                value: 'server',
              ),
              BullSelectableListItem(
                title: 'Private',
                subtitle1: '',
                subtitle2: '',
                value: 'private',
              ),
            ],
          ),
        ),
      ),
    );
    final privateCard = find.byKey(const ValueKey('Private'));
    expect(
      find.descendant(
        of: privateCard,
        matching: find.byIcon(Icons.radio_button_unchecked),
      ),
      findsOneWidget,
    );
    final semantics = find
        .descendant(of: privateCard, matching: find.byType(Semantics))
        .first;
    expect(tester.widget<Semantics>(semantics).properties.selected, isFalse);
    expect(
      tester.widget<Semantics>(semantics).properties.inMutuallyExclusiveGroup,
      isTrue,
    );
    final tap = find.descendant(
      of: privateCard,
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(tap).onTap, isNotNull);
    await tester.tap(find.text('Private'));
    await tester.pumpAndSettle();
    expect(selected, 'private');
    expect(tester.widget<Semantics>(semantics).properties.selected, isTrue);
    expect(
      find.descendant(
        of: privateCard,
        matching: find.byIcon(Icons.radio_button_checked_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'callback selects in place and exposes the selected card to accessibility',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        wrapWithTheme(
          BullSelectableList(
            selectedValue: 'server',
            onChanged: (value) => selected = value,
            items: const [
              BullSelectableListItem(
                title: 'Server',
                subtitle1: 'Public fixture',
                subtitle2: '',
                value: 'server',
              ),
              BullSelectableListItem(
                title: 'Private',
                subtitle1: 'Public fixture',
                subtitle2: '',
                value: 'private',
              ),
            ],
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle();
      expect(selected, 'private');
      expect(find.text('Server'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
    },
  );
}
