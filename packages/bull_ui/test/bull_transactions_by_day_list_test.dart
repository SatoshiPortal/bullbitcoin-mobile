import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

void main() {
  testWidgets('keeps relative, custom and locale-specific day headings', (
    tester,
  ) async {
    await initializeDateFormatting('fr');
    final now = DateTime.now();
    const verifying = 8639999999999999;
    final today = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day - 1,
    ).millisecondsSinceEpoch;
    final future = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).millisecondsSinceEpoch;
    final lastYear = DateTime(now.year - 1, 5, 3).millisecondsSinceEpoch;

    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: const Locale('fr'),
            child: BullTransactionsByDayList<String>(
              itemsByDay: {
                today: const ['Today entry'],
                verifying: const ['Verifying entry'],
                future: const ['Pending entry'],
                yesterday: const ['Yesterday entry'],
                lastYear: const ['Older entry'],
              },
              dayLabel: (_, key) => key == verifying ? 'À vérifier' : null,
              pendingLabel: 'En attente',
              todayLabel: 'Aujourd’hui',
              yesterdayLabel: 'Hier',
              loadingMessage: 'Chargement',
              emptyMessage: 'Aucune transaction',
              itemBuilder: (_, item) => Text(item),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Aujourd’hui'), findsOneWidget);
    expect(find.text('À vérifier'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.text('Hier'), findsOneWidget);
    expect(find.text('3 mai ${now.year - 1}'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Today entry')).dy,
      lessThan(tester.getTopLeft(find.text('Verifying entry')).dy),
    );
  });

  testWidgets('retains a header and wraps placeholders in slivers', (
    tester,
  ) async {
    Future<void> show(Map<int, List<String>>? itemsByDay, {String? error}) {
      return tester.pumpWidget(
        wrapWithTheme(
          CustomScrollView(
            slivers: [
              BullTransactionsByDayList<String>(
                sliver: true,
                itemsByDay: itemsByDay,
                header: const Text('Ongoing swaps'),
                errorMessage: error,
                pendingLabel: 'Pending',
                todayLabel: 'Today',
                yesterdayLabel: 'Yesterday',
                loadingMessage: 'Loading',
                emptyMessage: 'No entries',
                itemBuilder: (_, item) => Text(item),
              ),
            ],
          ),
        ),
      );
    }

    await show(const {});
    expect(find.text('Ongoing swaps'), findsOneWidget);
    expect(find.text('No entries'), findsNothing);

    await show(null);
    expect(find.text('Loading'), findsOneWidget);
    expect(find.byType(SliverToBoxAdapter), findsOneWidget);
    expect(find.text('Ongoing swaps'), findsNothing);

    await show(null, error: 'Unavailable');
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Loading'), findsNothing);
  });
}
