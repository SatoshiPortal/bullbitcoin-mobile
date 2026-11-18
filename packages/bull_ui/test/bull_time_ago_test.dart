import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final clock = DateTime(2026, 11, 17, 12);
  final twoHoursAgo = clock.subtract(const Duration(hours: 2));

  Future<String> timeAgoIn(WidgetTester tester, Locale locale) async {
    late String text;
    await tester.pumpWidget(
      Localizations(
        locale: locale,
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Builder(
          builder: (context) {
            text = bullTimeAgo(context, twoHoursAgo, clock: clock);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return text;
  }

  testWidgets('follows the app language', (tester) async {
    expect(await timeAgoIn(tester, const Locale('fr')), 'il y a 2 heures');
    expect(await timeAgoIn(tester, const Locale('pt', 'BR')), 'há 2 horas');
  });

  testWidgets('reads in English where timeago has no messages', (tester) async {
    expect(await timeAgoIn(tester, const Locale('bg')), '2 hours ago');
    expect(
      await timeAgoIn(
        tester,
        const Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'),
      ),
      '2 hours ago',
    );
  });
}
