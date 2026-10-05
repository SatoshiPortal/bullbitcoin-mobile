// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class LogsLocalizationsFr extends LogsLocalizations {
  LogsLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Journaux';

  @override
  String get logsViewerDeleteButton => 'Supprimer';

  @override
  String get logsViewerFilter => 'Filtrer les journaux';

  @override
  String get logsViewerShareButton => 'Partager';

  @override
  String get logsShareFailedMessage => 'Échec du partage des logs';

  @override
  String get logsExportedMessage => 'Journaux exportés avec succès';

  @override
  String get logsExportFailedMessage => 'Échec de l\'exportation des journaux';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'Affichage de $shown sur $total journaux';
  }

  @override
  String get logsViewerCollapseAll => 'Replier tout';

  @override
  String get logsViewerWrapAll => 'Déplier tout';

  @override
  String get logsViewerEmpty => 'Aucun journal pour le moment';

  @override
  String get logsViewerNoMatches =>
      'Aucun journal ne correspond aux filtres actifs';

  @override
  String get logsViewerClearFilter => 'Effacer le filtre';

  @override
  String get logsViewerSearchHint => 'Rechercher dans les logs';

  @override
  String get logsViewerFilterByDate => 'Filtrer par date';

  @override
  String get logsViewerCollapseHint =>
      'Touchez pour replier. Appuyez longuement pour copier.';

  @override
  String get logsViewerExpandHint =>
      'Touchez un journal pour le déplier. Appuyez longuement pour le copier.';

  @override
  String get copiedToClipboardMessage => 'Copié dans le presse-papiers';

  @override
  String get logsViewerDeleteTitle => 'Supprimer les journaux';

  @override
  String get logsViewerDeleteConfirmation =>
      'Voulez-vous vraiment supprimer tous les journaux ? Cette action est irréversible.';

  @override
  String get logsDeletedMessage => 'Journaux supprimés';

  @override
  String get logsViewerCancelButton => 'Annuler';

  @override
  String get logsShareOptionShare => 'Partager';

  @override
  String get logsShareOptionExport => 'Exporter';

  @override
  String get oopsSomethingWentWrong => 'Oups ! Une erreur s\'est produite';

  @override
  String get retry => 'Réessayer';
}
