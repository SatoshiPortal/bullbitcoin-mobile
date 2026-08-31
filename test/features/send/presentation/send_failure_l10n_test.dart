import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/presentation/send_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<String> translated(
    WidgetTester tester,
    Locale locale,
    SendFailure failure,
  ) async {
    late String message;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            message = failure.toTranslated(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return message;
  }

  testWidgets('selected coin failures use the English messages', (
    tester,
  ) async {
    expect(
      await translated(
        tester,
        const Locale('en'),
        const SendSelectedCoinsUnavailableFailure(),
      ),
      'One or more selected coins are no longer available. Review your coin selection and try again.',
    );
    expect(
      await translated(
        tester,
        const Locale('en'),
        const SendSelectedCoinsInsufficientFailure(),
      ),
      'The selected coins do not cover the amount and fees. Select more coins or reduce the amount.',
    );
  });

  testWidgets('selected coin failures use the French messages', (tester) async {
    expect(
      await translated(
        tester,
        const Locale('fr'),
        const SendSelectedCoinsUnavailableFailure(),
      ),
      'Un ou plusieurs coins sélectionnés ne sont plus disponibles. Vérifiez votre sélection et réessayez.',
    );
    expect(
      await translated(
        tester,
        const Locale('fr'),
        const SendSelectedCoinsInsufficientFailure(),
      ),
      'Les coins sélectionnés ne couvrent pas le montant et les frais. Sélectionnez plus de coins ou réduisez le montant.',
    );
  });
}
