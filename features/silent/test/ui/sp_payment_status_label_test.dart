import 'package:bull_ui/testing.dart';
import 'package:silent/src/domain/entities/sp_payment.dart';
import 'package:silent/src/ui/widgets/sp_tx_list_item.dart';
import 'package:silent/localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

void main() {
  testWidgets('dates a verified payment in the app language', (tester) async {
    final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: const [
          SilentLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: SilentLocalizations.supportedLocales,
        home: Scaffold(
          body: SpPaymentStatusLabel(
            payment: SpPayment(
              txid: 'a' * 64,
              direction: SpPaymentDirection.receive,
              status: SpPaymentStatus.verified,
              amountSat: Sats(BigInt.from(1000)),
              timestamp: BigInt.from(
                twoHoursAgo.millisecondsSinceEpoch ~/ 1000,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('il y a 2 heures'), findsOneWidget);
  });
}
