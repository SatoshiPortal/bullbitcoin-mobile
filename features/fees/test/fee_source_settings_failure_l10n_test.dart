import 'package:fees_feature/fees_feature.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const load = FeeSourceSettingsLoadFailure();
  const save = FeeSourceSettingsSaveFailure();

  for (final (locale, loadMessage, saveMessage) in const [
    (
      Locale('fr', 'CA'),
      'Impossible de charger la source des frais.',
      'Impossible d’enregistrer ce choix. La source précédente est toujours active.',
    ),
    (
      Locale('es', 'MX'),
      'No se pudo cargar la fuente de comisiones.',
      'No se pudo guardar esta opción. La fuente anterior sigue activa.',
    ),
    (
      Locale('de'),
      'Could not load the fee source.',
      'Could not save this choice. Your previous source is still active.',
    ),
  ]) {
    testWidgets('translates both fee source failures for $locale', (
      tester,
    ) async {
      late BuildContext localizedContext;
      await tester.pumpWidget(
        Localizations(
          locale: locale,
          delegates: const [GlobalWidgetsLocalizations.delegate],
          child: Builder(
            builder: (context) {
              localizedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(load.toTranslated(localizedContext), loadMessage);
      expect(save.toTranslated(localizedContext), saveMessage);
    });
  }
}
