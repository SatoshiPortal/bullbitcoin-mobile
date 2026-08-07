import 'package:bb_mobile/features/transactions/presentation/order_swap_status_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Renders the extension against a real localized context and returns what
  /// the details row would display.
  Future<String> translated(WidgetTester tester, String raw) async {
    late String result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            result = raw.toTranslatedOrderStatus(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('In_pending renders as Pending, not the raw code (#2567)', (
    tester,
  ) async {
    expect(await translated(tester, 'In_pending'), 'Pending');
  });

  testWidgets('the readable API values are localized too', (tester) async {
    expect(await translated(tester, 'Completed'), 'Completed');
    expect(await translated(tester, 'In progress'), 'In Progress');
    expect(await translated(tester, 'Awaiting payment'), 'Awaiting payment');
    expect(await translated(tester, 'Not started'), 'Not started');
    expect(
      await translated(tester, 'Payment deadline expired'),
      'Payment deadline expired',
    );
    expect(await translated(tester, 'Expired'), 'Expired');
    expect(await translated(tester, 'Failed'), 'Failed');
  });

  testWidgets('matching ignores case, padding and underscores', (tester) async {
    expect(await translated(tester, '  in progress  '), 'In Progress');
    expect(await translated(tester, 'IN_PROGRESS'), 'In Progress');
    expect(await translated(tester, 'completed'), 'Completed');
  });

  testWidgets('both spellings of canceled map to one label', (tester) async {
    expect(await translated(tester, 'Canceled'), 'Canceled');
    expect(await translated(tester, 'Cancelled'), 'Canceled');
  });

  testWidgets('an unrecognized status is humanized, never shown raw', (
    tester,
  ) async {
    expect(await translated(tester, 'Some_future_code'), 'Some future code');
    expect(await translated(tester, 'Out_pending'), 'Out pending');
  });

  testWidgets('an empty status falls back to Unknown', (tester) async {
    expect(await translated(tester, ''), 'Unknown');
  });
}
