import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/recipients/public/recipient_view_model.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/recipients_list_tile.dart';
import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_ui/bull_ui.dart' show BullIcon, BullIcons;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _iban = 'FR7616958000016918327146718';
final _recipient = RecipientViewModel(
  Recipient.create(
    recipientId: 'saved-sepa',
    userId: 'user',
    userNbr: 1,
    isArchived: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    details: SepaEurDetails.create(
      iban: _iban,
      isCorporate: false,
      firstname: 'Satoshi',
      lastname: 'Nakamoto',
    ),
  ),
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
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
          supportedLocales: ExchangeLocalizations.supportedLocales,
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
      allOf(contains('Satoshi Nakamoto'), contains(_iban)),
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
