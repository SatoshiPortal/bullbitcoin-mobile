import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/transactions/presentation/order_payment_method_l10n.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<String> translated(
    WidgetTester tester,
    OrderPaymentMethod method,
  ) async {
    late String result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            result = method.toTranslated(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('e-transfer orders show the generic label, not the trademark', (
    tester,
  ) async {
    final label = await translated(tester, OrderPaymentMethod.eTransfer);

    expect(label, 'Email Money Transfer (CAD)');
    expect(label.toLowerCase(), isNot(contains('interac')));
  });

  test('the wire value still parses back from the API string', () {
    expect(
      OrderPaymentMethod.fromValue('Interac e-Transfer (CAD)'),
      OrderPaymentMethod.eTransfer,
    );
  });

  testWidgets('other methods keep the exchange label', (tester) async {
    expect(
      await translated(tester, OrderPaymentMethod.sepa),
      'SEPA Transfer (EUR)',
    );
  });
}
