import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bb_mobile/features/transactions/presentation/transaction_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The kind of text a transaction failure can carry: an exception class name
/// plus a txid and an address, none of which may be shown.
const _txid =
    '4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b';
const _address = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
const _rawReason = 'StateError: no swap for tx $_txid paying to $_address';

const _everyFailure = <TransactionFailure>[
  TransactionAggregationFailure(_rawReason),
  TransactionNotFoundFailure(_rawReason),
  TransactionSwapUnavailableFailure(_rawReason),
  TransactionExportEmptyFailure(_rawReason),
  TransactionExportInvalidRangeFailure(_rawReason),
  TransactionExportFailure(_rawReason),
  TransactionPayjoinFallbackUnavailableFailure(_rawReason),
  TransactionPayjoinBroadcastFailure(_rawReason),
  TransactionLabelLimitFailure(_rawReason),
  TransactionUnexpectedFailure(_rawReason),
];

Future<String> _translate(
  WidgetTester tester,
  TransactionFailure failure,
) async {
  late String translated;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          translated = failure.toTranslated(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  return translated;
}

void main() {
  testWidgets('no variant ever renders the raw reason', (tester) async {
    for (final failure in _everyFailure) {
      final message = await _translate(tester, failure);

      expect(message, isNotEmpty);
      expect(
        message,
        isNot(contains(_txid)),
        reason: '${failure.runtimeType} leaked a txid',
      );
      expect(
        message,
        isNot(contains(_address)),
        reason: '${failure.runtimeType} leaked an address',
      );
      expect(
        message,
        isNot(contains('StateError')),
        reason: '${failure.runtimeType} leaked an exception class name',
      );
    }
  });

  testWidgets('each mapped failure reads differently from the catch-all', (
    tester,
  ) async {
    final generic = await _translate(
      tester,
      const TransactionUnexpectedFailure(),
    );

    for (final failure in _everyFailure) {
      if (failure is TransactionUnexpectedFailure) continue;
      expect(
        await _translate(tester, failure),
        isNot(generic),
        reason:
            '${failure.runtimeType} is indistinguishable from the generic '
            'message, so the user learns nothing from it',
      );
    }
  });
}
