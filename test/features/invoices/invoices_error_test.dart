import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_error.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InvoicesException.fromBullnym', () {
    InvoicesException fromCode(String code, {bool retryable = false}) {
      return InvoicesException.fromBullnym(
        BullnymException.serverRejectedRequest(
          code: code,
          diagnosticReason: 'diagnostic only',
          retryable: retryable,
        ),
      );
    }

    test('maps every stable invoice server code to its variant', () {
      expect(fromCode('InvoiceNotFound').kind, InvoicesErrorKind.notFound);
      expect(fromCode('InvalidAmount').kind, InvoicesErrorKind.invalidInput);
      expect(fromCode('AuthError').kind, InvoicesErrorKind.authError);
      expect(
        fromCode('BitcoinAddressAlreadyUsed').kind,
        InvoicesErrorKind.reusedBitcoinAddress,
      );
      expect(
        fromCode('LiquidAddressAlreadyUsed').kind,
        InvoicesErrorKind.reusedLiquidAddress,
      );
      expect(fromCode('RateLimitedSender').kind, InvoicesErrorKind.rateLimited);
      expect(fromCode('RateLimitedNetwork').kind, InvoicesErrorKind.rateLimited);
      expect(
        fromCode('ServiceUnavailable', retryable: true).kind,
        InvoicesErrorKind.server,
      );
      expect(fromCode('SomethingNew').kind, InvoicesErrorKind.server);
    });

    test('maps transport kinds and a route-absent 404 (fail-closed)', () {
      expect(
        InvoicesException.fromBullnym(
          const BullnymException.network(diagnosticReason: 'x'),
        ).kind,
        InvoicesErrorKind.network,
      );
      expect(
        InvoicesException.fromBullnym(
          const BullnymException.timeout(diagnosticReason: 'x'),
        ).kind,
        InvoicesErrorKind.timeout,
      );
      // Feature-disabled / pre-flag server (route absent) → a loud server error.
      final failClosed = InvoicesException.fromBullnym(
        const BullnymException.unexpectedHttpStatus(statusCode: 404),
      );
      expect(failClosed.kind, InvoicesErrorKind.server);
      expect(
        InvoicesException.fromBullnym(
          const BullnymException.invalidServerResponse(),
        ).kind,
        InvoicesErrorKind.invalidServerResponse,
      );
      expect(
        InvoicesException.fromBullnym(const BullnymException.signingFailed()).kind,
        InvoicesErrorKind.signingFailed,
      );
    });

    test('never surfaces the server reason string', () {
      final error = InvoicesException.fromBullnym(
        const BullnymException.serverRejectedRequest(
          code: 'InvalidAmount',
          diagnosticReason: 'secret-diagnostic-detail',
          retryable: false,
        ),
      );
      expect(error.toString(), isNot(contains('secret-diagnostic-detail')));
    });
  });

  group('InvoicesException.toTranslated', () {
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

      const variants = <InvoicesException>[
        InvoicesException.noDefaultBitcoinWallet(),
        InvoicesException.noDefaultLiquidWallet(),
        InvoicesException.invalidInput(code: 'X'),
        InvoicesException.reusedBitcoinAddress(),
        InvoicesException.reusedLiquidAddress(),
        InvoicesException.notFound(),
        InvoicesException.authError(),
        InvoicesException.rateLimited(),
        InvoicesException.network(),
        InvoicesException.timeout(),
        InvoicesException.invalidServerResponse(),
        InvoicesException.signingFailed(),
        InvoicesException.server(retryable: true),
        InvoicesException.unexpected(),
      ];

      for (final variant in variants) {
        expect(variant.toTranslated(ctx), isNotEmpty);
      }
    });
  });
}
