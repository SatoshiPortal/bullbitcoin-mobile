import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/pos/domain/pos_error.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PosException.fromBullnym', () {
    test('maps every stable server code to its variant', () {
      PosException fromCode(String code, {bool retryable = false}) {
        return PosException.fromBullnym(
          BullnymException.serverRejectedRequest(
            code: code,
            diagnosticReason: 'diagnostic only',
            retryable: retryable,
          ),
        );
      }

      expect(fromCode('DonationPageNotFound').kind, PosErrorKind.notFound);
      // KR-1: the server hard-fails a descriptorless kind=pos save as
      // DonationPageInvalid (no LA-cursor fallback for the pos branch).
      expect(fromCode('DonationPageInvalid').kind, PosErrorKind.rejected);
      expect(fromCode('AuthError').kind, PosErrorKind.authError);
      // A retryable, otherwise-unknown server rejection degrades to `server`.
      expect(
        fromCode('ServiceUnavailable', retryable: true).kind,
        PosErrorKind.server,
      );
      // A non-retryable unknown rejection is surfaced as a plain rejection.
      expect(fromCode('SomethingNew').kind, PosErrorKind.rejected);
    });

    test('maps transport error kinds through', () {
      expect(
        PosException.fromBullnym(
          const BullnymException.network(diagnosticReason: 'x'),
        ).kind,
        PosErrorKind.network,
      );
      expect(
        PosException.fromBullnym(
          const BullnymException.timeout(diagnosticReason: 'x'),
        ).kind,
        PosErrorKind.timeout,
      );
      expect(
        PosException.fromBullnym(
          const BullnymException.invalidServerResponse(),
        ).kind,
        PosErrorKind.invalidServerResponse,
      );
      expect(
        PosException.fromBullnym(const BullnymException.signingFailed()).kind,
        PosErrorKind.signingFailed,
      );
    });

    test('never surfaces the server reason string', () {
      final error = PosException.fromBullnym(
        const BullnymException.serverRejectedRequest(
          code: 'DonationPageInvalid',
          diagnosticReason: 'ct_descriptor empty: secret-diagnostic',
          retryable: false,
        ),
      );
      expect(error.toString(), isNot(contains('secret-diagnostic')));
    });
  });

  group('PosException.toTranslated', () {
    testWidgets('every kind renders non-empty localized copy', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      final variants = <PosException>[
        const PosException.invalidInput(code: 'X'),
        const PosException.noNym(),
        const PosException.noDefaultBitcoinWallet(),
        const PosException.localPreparationFailed(code: 'X', retryable: true),
        const PosException.network(),
        const PosException.timeout(),
        const PosException.notFound(),
        const PosException.rejected(code: 'X'),
        const PosException.authError(),
        const PosException.server(retryable: true),
        const PosException.invalidServerResponse(),
        const PosException.signingFailed(),
        const PosException.unexpected(),
      ];

      for (final variant in variants) {
        expect(variant.toTranslated(ctx), isNotEmpty);
      }
    });
  });
}
