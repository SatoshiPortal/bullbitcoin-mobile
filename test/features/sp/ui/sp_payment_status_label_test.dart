import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_tx_list_item.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

void main() {
  testWidgets('dates a verified payment in the app language', (tester) async {
    final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
