// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'quick_actions_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class QuickActionsLocalizationsFr extends QuickActionsLocalizations {
  QuickActionsLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get buy => 'Acheter';

  @override
  String get sell => 'Vendre';

  @override
  String get pay => 'Payer';

  @override
  String get transfer => 'Transfert';

  @override
  String get map => 'Carte';

  @override
  String get settings => 'Réglages';

  @override
  String get more => 'Plus';

  @override
  String get customize => 'Personnaliser';

  @override
  String get title => 'Actions rapides';

  @override
  String get reset => 'Rétablir par défaut';

  @override
  String get moveUp => 'Monter';

  @override
  String get moveDown => 'Descendre';

  @override
  String get saveFailed => 'Impossible d’enregistrer. Veuillez réessayer.';

  @override
  String get loading => 'Chargement';

  @override
  String get history => 'Historique';

  @override
  String get support => 'Aide';

  @override
  String get priceHistory => 'Prix';

  @override
  String get quickActionTrade => 'Trade';

  @override
  String get onHome => 'Sur l’accueil';

  @override
  String get inMore => 'Dans Plus';

  @override
  String get preview => 'Aperçu';

  @override
  String get maximumHint => 'Choisissez jusqu’à 3 actions pour l’accueil.';

  @override
  String addAction(String name) {
    return 'Ajouter $name à l’accueil';
  }

  @override
  String removeAction(String name) {
    return 'Déplacer $name dans Plus';
  }

  @override
  String reorderAction(String name) {
    return 'Réorganiser $name';
  }

  @override
  String get edit => 'Modifier';

  @override
  String get close => 'Fermer';

  @override
  String get priceHistoryFull => 'Historique des prix';

  @override
  String get saving => 'Enregistrement…';

  @override
  String get emptyHint =>
      'Aucune action sélectionnée. Réglages reste sur l’accueil.';

  @override
  String get supportFull => 'Assistance';

  @override
  String get homeFullHint =>
      'L’accueil contient 3 actions. Retirez-en une pour en ajouter une autre.';

  @override
  String get defaultsRestored => 'Actions par défaut rétablies.';

  @override
  String get undo => 'Annuler';
}
