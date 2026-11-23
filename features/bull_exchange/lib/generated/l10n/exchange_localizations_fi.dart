// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Finnish (`fi`).
class ExchangeLocalizationsFi extends ExchangeLocalizations {
  ExchangeLocalizationsFi([String locale = 'fi']) : super(locale);

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Lokien liittäminen epäonnistui. Yritä uudelleen.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'Kuva';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Tuntematon tiedosto';

  @override
  String get exchangeSupportChatEmptyState =>
      'Ei viestejä vielä. Aloita keskustelu!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Tiedostotietojen haku epäonnistui.';

  @override
  String get exchangeSupportChatInputHint => 'Kirjoita viesti...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Liitteen avaaminen epäonnistui. Yritä uudelleen.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Viestien lataaminen epäonnistui. Yritä uudelleen.';

  @override
  String get exchangeSupportChatMessageEmptyError => 'Viesti ei voi olla tyhjä';

  @override
  String get exchangeSupportChatMessageRequired =>
      'Liite vaatii viestiin sisältöä';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Tiedostojen valinta epäonnistui. Yritä uudelleen.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Viestin lähettäminen epäonnistui. Yritä uudelleen.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'Tukichatti';

  @override
  String get exchangeSupportChatYesterday => 'Eilen';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Saadaksesi henkilökohtaista tukea sinun on ensin kirjauduttava Bull Bitcoin -tilillesi. Se on 100 % ilmaista eikä KYC:tä vaadita, ainoastaan sähköpostiosoite.';

  @override
  String get oopsSomethingWentWrong => 'Hups! Jotain meni pieleen';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}
