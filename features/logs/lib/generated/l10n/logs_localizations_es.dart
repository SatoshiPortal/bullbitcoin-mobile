// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class LogsLocalizationsEs extends LogsLocalizations {
  LogsLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Registros';

  @override
  String get logsViewerDeleteButton => 'Eliminar';

  @override
  String get logsViewerFilter => 'Filtrar registros';

  @override
  String get logsViewerShareButton => 'Compartir';

  @override
  String get logsShareFailedMessage => 'Error al compartir los registros';

  @override
  String get logsExportedMessage => 'Registros exportados correctamente';

  @override
  String get logsExportFailedMessage => 'Error al exportar los registros';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'Mostrando $shown de $total registros';
  }

  @override
  String get logsViewerCollapseAll => 'Contraer todo';

  @override
  String get logsViewerWrapAll => 'Expandir todo';

  @override
  String get logsViewerEmpty => 'Aún no hay registros';

  @override
  String get logsViewerNoMatches =>
      'Ningún registro coincide con los filtros activos';

  @override
  String get logsViewerClearFilter => 'Borrar filtro';

  @override
  String get logsViewerSearchHint => 'Buscar en los registros';

  @override
  String get logsViewerFilterByDate => 'Filtrar por fecha';

  @override
  String get logsViewerCollapseHint =>
      'Toca para contraer. Mantén pulsado para copiar.';

  @override
  String get logsViewerExpandHint =>
      'Toca un registro para expandirlo. Mantén pulsado para copiarlo.';

  @override
  String get copiedToClipboardMessage => 'Copiado al portapapeles';

  @override
  String get logsViewerDeleteTitle => 'Eliminar registros';

  @override
  String get logsViewerDeleteConfirmation =>
      '¿Está seguro de que desea eliminar todos los registros? Esta acción no se puede deshacer.';

  @override
  String get logsDeletedMessage => 'Registros eliminados';

  @override
  String get logsViewerCancelButton => 'Cancelar';

  @override
  String get logsShareOptionShare => 'Compartir';

  @override
  String get logsShareOptionExport => 'Exportar';

  @override
  String get oopsSomethingWentWrong => '¡Ups! Algo salió mal';

  @override
  String get retry => 'Reintentar';
}
