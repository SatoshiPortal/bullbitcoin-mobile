import 'package:address_view/routes.dart' show AddressViewLocalizations;
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:label_editor/label_editor.dart' show LabelEditorLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:scanning/scanning.dart' show ScanningLocalizations;
import 'package:send/setup.dart' show SendLocalizations;
import 'package:signers/routes.dart' show SignersLocalizations;
import 'package:silent/localizations.dart' show SilentLocalizations;

const sendTestLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  SendLocalizations.delegate,
  AddressViewLocalizations.delegate,
  SilentLocalizations.delegate,
  ScanningLocalizations.delegate,
  LabelEditorLocalizations.delegate,
  SignersLocalizations.delegate,
  bullUiLocalizationsDelegate,
  ...GlobalMaterialLocalizations.delegates,
];
