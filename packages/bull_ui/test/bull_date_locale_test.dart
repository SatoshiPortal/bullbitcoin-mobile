import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<String> dateLocaleIn(WidgetTester tester, Locale locale) async {
    late String name;
    await tester.pumpWidget(
      Localizations(
        locale: locale,
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Builder(
          builder: (context) {
            name = bullDateLocale(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return name;
  }

  testWidgets('follows the app language', (tester) async {
    expect(await dateLocaleIn(tester, const Locale('fr')), 'fr');
    expect(await dateLocaleIn(tester, const Locale('pt', 'BR')), 'pt_BR');
  });

  testWidgets('reads in English for a script intl does not key dates by', (
    tester,
  ) async {
    expect(
      await dateLocaleIn(
        tester,
        const Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'),
      ),
      'en',
    );
  });
}
