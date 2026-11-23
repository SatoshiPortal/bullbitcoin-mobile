import 'package:wallet_import/generated/l10n/import_localizations.dart';
import 'package:material_ui/material_ui.dart' show BuildContext;

extension ImportL10n on BuildContext {
  ImportLocalizations get loc => ImportLocalizations.of(this);
}
