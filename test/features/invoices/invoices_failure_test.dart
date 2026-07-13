import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:bb_mobile/features/invoices/presentation/invoices_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InvoicesFailure', () {
    test('preserves stable code and retryability metadata', () {
      const retryable = <InvoicesFailure>[
        InvoicesFailure.rateLimited(),
        InvoicesFailure.network(),
        InvoicesFailure.timeout(),
        InvoicesFailure.invalidServerResponse(),
        InvoicesFailure.server(retryable: true),
      ];
      const terminal = <InvoicesFailure>[
        InvoicesFailure.noDefaultBitcoinWallet(),
        InvoicesFailure.noDefaultLiquidWallet(),
        InvoicesFailure.invalidInput(code: 'X'),
        InvoicesFailure.reusedBitcoinAddress(),
        InvoicesFailure.reusedLiquidAddress(),
        InvoicesFailure.notFound(),
        InvoicesFailure.authError(),
        InvoicesFailure.signingFailed(),
        InvoicesFailure.unexpected(),
      ];

      expect(retryable.every((failure) => failure.retryable), isTrue);
      expect(terminal.every((failure) => !failure.retryable), isTrue);
      expect(const InvoicesFailure.notFound().code, 'InvoiceNotFound');
      expect(
        const InvoicesFailure.reusedBitcoinAddress().code,
        'BitcoinAddressAlreadyUsed',
      );
    });

    testWidgets('every variant renders sanitized localized copy', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );

      const variants = <InvoicesFailure>[
        InvoicesFailure.noDefaultBitcoinWallet(),
        InvoicesFailure.noDefaultLiquidWallet(),
        InvoicesFailure.invalidInput(code: 'X'),
        InvoicesFailure.reusedBitcoinAddress(),
        InvoicesFailure.reusedLiquidAddress(),
        InvoicesFailure.notFound(),
        InvoicesFailure.authError(),
        InvoicesFailure.rateLimited(),
        InvoicesFailure.network(),
        InvoicesFailure.timeout(),
        InvoicesFailure.invalidServerResponse(),
        InvoicesFailure.signingFailed(),
        InvoicesFailure.server(retryable: true),
        InvoicesFailure.unexpected('diagnostic-only'),
      ];

      for (final failure in variants) {
        final copy = failure.toTranslated(context);
        expect(copy, isNotEmpty);
        expect(copy, isNot(contains('diagnostic-only')));
      }
    });
  });
}
