import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/ui/fiat_settlement_copy.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('activated title maps each product to its own success headline', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(
      ctx.fiatSettlementActivatedTitle(FiatSettlementProduct.lightningAddress),
      'Your Lightning Address has been activated',
    );
    expect(
      ctx.fiatSettlementActivatedTitle(FiatSettlementProduct.paymentPage),
      'Your Payment Page has been activated',
    );
    expect(
      ctx.fiatSettlementActivatedTitle(FiatSettlementProduct.pos),
      'Your Point of Sale has been activated',
    );
    // Invoices have no activation moment, so the header falls back to the
    // generic section title rather than inventing an "activated" headline.
    expect(
      ctx.fiatSettlementActivatedTitle(FiatSettlementProduct.invoice),
      ctx.loc.getPaidFiatSettlementSectionTitle,
    );
    // The chooser badge marking the currently-active option.
    expect(ctx.loc.getPaidFiatSettlementCurrentlyActive, 'Currently active');
  });
}
