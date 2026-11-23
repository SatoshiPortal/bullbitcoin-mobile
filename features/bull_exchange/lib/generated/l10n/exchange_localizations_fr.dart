// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class ExchangeLocalizationsFr extends ExchangeLocalizations {
  ExchangeLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Joindre un fichier';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Échec de l\'ajout des journaux. Veuillez réessayer.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Joindre les journaux';

  @override
  String get exchangeSupportChatAttachmentImage => 'Image';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Fichier inconnu';

  @override
  String get exchangeSupportChatEmptyState =>
      'Aucun message pour le moment. Commencez une conversation !';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Échec de la récupération des données du fichier.';

  @override
  String get exchangeSupportChatInputHint => 'Tapez un message...';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Impossible d\'ouvrir la pièce jointe. Veuillez réessayer.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Impossible de charger les messages. Veuillez réessayer.';

  @override
  String get exchangeSupportChatMessageEmptyError =>
      'Le message ne peut pas être vide';

  @override
  String get exchangeSupportChatMessageRequired => 'Un message est requis';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Échec de la sélection des fichiers. Veuillez réessayer.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Impossible d\'envoyer votre message. Veuillez réessayer.';

  @override
  String get exchangeSupportChatSendTooltip => 'Envoyer le message';

  @override
  String get exchangeSupportChatTitle => 'Chat de Support';

  @override
  String get exchangeSupportChatYesterday => 'Hier';

  @override
  String get exchangeSupportLoginChatRequired =>
      'Pour obtenir de l\'aide humaine, vous devez d\'abord vous connecter à votre compte Bull Bitcoin. C\'est 100 % gratuit et aucun KYC n\'est requis, seulement une adresse courriel.';

  @override
  String get oopsSomethingWentWrong => 'Oups ! Une erreur s\'est produite';

  @override
  String get exchangeSupportChatLogDraft => 'Voici mes journaux';
}
