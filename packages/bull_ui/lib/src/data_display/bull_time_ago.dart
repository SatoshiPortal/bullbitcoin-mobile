import 'package:flutter/widgets.dart';
import 'package:timeago/timeago.dart' as timeago;

/// How long ago [date] was ("5 minutes ago"), in the app's language.
///
/// Languages timeago has no messages for read in English.
String bullTimeAgo(BuildContext context, DateTime date, {DateTime? clock}) =>
    timeago.format(
      date,
      locale: _registeredLocale(Localizations.localeOf(context)),
      clock: clock,
    );

final _registered = <String>{};

String _registeredLocale(Locale locale) {
  final messages = _messagesFor(locale);
  if (messages == null) return 'en';
  final key = locale.toLanguageTag();
  if (_registered.add(key)) timeago.setLocaleMessages(key, messages);
  return key;
}

timeago.LookupMessages? _messagesFor(Locale locale) =>
    switch (locale.languageCode) {
      'ar' => timeago.ArMessages(),
      'bn' => timeago.BnMessages(),
      'cs' => timeago.CsMessages(),
      'de' => timeago.DeMessages(),
      'el' => timeago.GrMessages(),
      'es' => timeago.EsMessages(),
      'fa' => timeago.FaMessages(),
      'fi' => timeago.FiMessages(),
      'fr' => timeago.FrMessages(),
      // Hinglish is written in Latin script, Hindi messages in Devanagari.
      'hi' when locale.scriptCode == null => timeago.HiMessages(),
      'it' => timeago.ItMessages(),
      'ko' => timeago.KoMessages(),
      // Portugal and Brazil phrase relative times alike.
      'pt' => timeago.PtBrMessages(),
      'ru' => timeago.RuMessages(),
      'th' => timeago.ThMessages(),
      'tr' => timeago.TrMessages(),
      'uk' => timeago.UkMessages(),
      'vi' => timeago.ViMessages(),
      'zh' => timeago.ZhCnMessages(),
      _ => null,
    };
