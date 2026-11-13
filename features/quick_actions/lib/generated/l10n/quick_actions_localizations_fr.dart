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
  String get transfer => 'Transférer';

  @override
  String get map => 'Cartes';

  @override
  String get settings => 'Réglages';

  @override
  String get more => 'Plus';

  @override
  String get customize => 'Personnaliser';

  @override
  String get title => 'Actions rapides';

  @override
  String get save => 'Enregistrer';

  @override
  String get reset => 'Rétablir par défaut';

  @override
  String get unavailable => 'Actuellement indisponible';

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
  String get support => 'Assistance';

  @override
  String get priceHistory => 'Historique des prix';

  @override
  String get quickActionTrade => 'Trade';

  @override
  String selectedCount(int count) {
    return 'Sélection : $count';
  }
}
