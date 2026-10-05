import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('finalization failure maps to its localized message', (
    tester,
  ) async {
    late String message;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            message = const PsbtFinalizationFailure().toTranslated(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(message, l10n.broadcastSignedTxErrorPsbtFinalization);
    expect(message, isNot(l10n.broadcastSignedTxErrorInvalidTransaction));
  });
}
