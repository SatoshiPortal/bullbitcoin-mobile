import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentPageException.fromBullnym', () {
    test('maps every stable server code to its variant', () {
      PaymentPageException fromCode(String code, {bool retryable = false}) {
        return PaymentPageException.fromBullnym(
          BullnymFailure.serverRejectedRequest(
            code: code,
            logMessage: 'diagnostic only',
            retryable: retryable,
          ),
        );
      }

      expect(
        fromCode('DonationPageNotFound').kind,
        PaymentPageErrorKind.notFound,
      );
      expect(
        fromCode('DonationPageInvalid').kind,
        PaymentPageErrorKind.rejected,
      );
      expect(fromCode('NameTaken').kind, PaymentPageErrorKind.aliasTaken);
      expect(fromCode('AuthError').kind, PaymentPageErrorKind.authError);
      // A retryable, otherwise-unknown server rejection degrades to `server`.
      expect(
        fromCode('ServiceUnavailable', retryable: true).kind,
        PaymentPageErrorKind.server,
      );
      // A non-retryable unknown rejection is surfaced as a plain rejection.
      expect(fromCode('SomethingNew').kind, PaymentPageErrorKind.rejected);
    });

    test('maps transport error kinds through', () {
      expect(
        PaymentPageException.fromBullnym(
          const BullnymFailure.network(logMessage: 'x'),
        ).kind,
        PaymentPageErrorKind.network,
      );
      expect(
        PaymentPageException.fromBullnym(
          const BullnymFailure.timeout(logMessage: 'x'),
        ).kind,
        PaymentPageErrorKind.timeout,
      );
      expect(
        PaymentPageException.fromBullnym(
          const BullnymFailure.invalidServerResponse(),
        ).kind,
        PaymentPageErrorKind.invalidServerResponse,
      );
      expect(
        PaymentPageException.fromBullnym(
          const BullnymFailure.signingFailed(),
        ).kind,
        PaymentPageErrorKind.signingFailed,
      );
    });

    test('never surfaces the server reason string', () {
      final error = PaymentPageException.fromBullnym(
        const BullnymFailure.serverRejectedRequest(
          code: 'DonationPageInvalid',
          logMessage: 'header too long: secret-diagnostic',
          retryable: false,
        ),
      );
      expect(error.toString(), isNot(contains('secret-diagnostic')));
    });

    test('AliasAlreadyAssigned requires and preserves typed owned alias', () {
      final mapped = PaymentPageException.fromBullnym(
        BullnymFailure.serverRejectedRequest(
          code: 'AliasAlreadyAssigned',
          logMessage: 'private detail',
          retryable: false,
          ownedNameDetails: BullnymOwnedAliasDetails(
            alias: BullnymPublicName('shop'),
          ),
        ),
      );
      expect(mapped.kind, PaymentPageErrorKind.aliasAlreadyAssigned);
      expect(mapped.ownedAlias, 'shop');

      final malformed = PaymentPageException.fromBullnym(
        const BullnymFailure.serverRejectedRequest(
          code: 'AliasAlreadyAssigned',
          logMessage: 'missing structured owner',
          retryable: false,
        ),
      );
      expect(malformed.kind, PaymentPageErrorKind.invalidServerResponse);
    });
  });

  group('PaymentPageException.toTranslated', () {
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

      final variants = <PaymentPageException>[
        const PaymentPageException.invalidInput(code: 'X'),
        const PaymentPageException.aliasTaken(),
        const PaymentPageException.aliasAlreadyAssigned(ownedAlias: 'shop'),
        const PaymentPageException.noNym(),
        const PaymentPageException.noDefaultBitcoinWallet(),
        const PaymentPageException.localPreparationFailed(
          code: 'X',
          retryable: true,
        ),
        const PaymentPageException.network(),
        const PaymentPageException.timeout(),
        const PaymentPageException.notFound(),
        const PaymentPageException.rejected(code: 'X'),
        const PaymentPageException.authError(),
        const PaymentPageException.server(retryable: true),
        const PaymentPageException.invalidServerResponse(),
        const PaymentPageException.signingFailed(),
        const PaymentPageException.unexpected(),
      ];

      for (final variant in variants) {
        expect(variant.toTranslated(ctx), isNotEmpty);
      }
    });
  });
}
