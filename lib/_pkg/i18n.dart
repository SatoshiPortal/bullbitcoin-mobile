import 'package:flutter_translate/flutter_translate.dart';

class Localise {
  static Future<LocalizationDelegate> getDelegate() async {
    final delegate = await LocalizationDelegate.create(
      fallbackLocale: 'en',
      supportedLocales: ['en', 'fr'],
    );

    return delegate;
  }
}
