import 'package:announcements/announcements.dart';
import 'package:bb_mobile/generated/novlang/novlang_announcements_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novlang/novlang.dart';

void main() {
  test(
    'the update announcement keeps the Apple vocabulary in every locale',
    () async {
      for (final locale in AnnouncementsLocalizations.supportedLocales) {
        final base = await AnnouncementsLocalizations.delegate.load(locale);
        final google = await const NovlangAnnouncementsLocalizationsDelegate(
          NovlangPolicy.google,
        ).load(locale);
        final apple = await const NovlangAnnouncementsLocalizationsDelegate(
          NovlangPolicy.apple,
        ).load(locale);
        expect(
          google.announcementAppUpdateRequiredDescription,
          base.announcementAppUpdateRequiredDescription,
        );
        expect(apple.localeName, base.localeName);
        expect(
          apple.announcementAppUpdateRequiredDescription,
          isNot(base.announcementAppUpdateRequiredDescription),
          reason: locale.toLanguageTag(),
        );
      }
      final english = await const NovlangAnnouncementsLocalizationsDelegate(
        NovlangPolicy.apple,
      ).load(const Locale('en'));
      expect(
        english.announcementAppUpdateRequiredDescription,
        contains('transfer service'),
      );
    },
  );
}
