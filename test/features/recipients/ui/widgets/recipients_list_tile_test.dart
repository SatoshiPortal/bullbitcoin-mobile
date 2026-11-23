import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';
import 'package:bb_mobile/features/recipients/public/recipient_view_model.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/recipients_list_tile.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullIcon, BullIcons;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _recipient = RecipientViewModel(
  id: 'saved-sepa',
  type: RecipientType.sepaEur,
  firstname: 'Satoshi',
  lastname: 'Nakamoto',
  iban: 'FR7616958000016918327146718',
);

void main() {
  testWidgets('announces the recipient and its single-choice selection state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var selections = 0;

    Future<void> pumpTile({required bool selected, bool enabled = true}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RecipientsListTile(
              recipient: _recipient,
              selected: selected,
              onTap: enabled ? () => selections++ : null,
            ),
          ),
        ),
      );
    }

    await pumpTile(selected: false);
    final unselected = tester.getSemantics(find.byType(RecipientsListTile));
    expect(
      unselected,
      isSemantics(
        hasCheckedState: true,
        isChecked: false,
        isInMutuallyExclusiveGroup: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      unselected.getSemanticsData().label,
      allOf(contains('Satoshi Nakamoto'), contains(_recipient.iban)),
    );
    expect(find.byType(BullIcon), findsNothing);
    await tester.tap(find.text('Satoshi Nakamoto'));
    expect(selections, 1);

    await pumpTile(selected: true);
    expect(
      tester.getSemantics(find.byType(RecipientsListTile)),
      isSemantics(isChecked: true, hasTapAction: true),
    );
    expect(
      tester.widget<BullIcon>(find.byType(BullIcon)).icon,
      BullIcons.checkCircle,
    );

    await pumpTile(selected: true, enabled: false);
    expect(
      tester.getSemantics(find.byType(RecipientsListTile)),
      isSemantics(isChecked: true, isEnabled: false, hasTapAction: false),
    );
    semantics.dispose();
  });
}
