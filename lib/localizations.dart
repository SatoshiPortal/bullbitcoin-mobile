import 'package:transactions/setup.dart' show TransactionsLocalizations;
import 'package:access/setup.dart' show AccessLocalizations;
import 'package:wallet_import/wallet_import.dart' show ImportLocalizations;
import 'package:bitcoin_price/bitcoin_price.dart'
    show BitcoinPriceLocalizations;
import 'package:announcements/announcements.dart'
    show AnnouncementsLocalizations;
import 'package:label_editor/label_editor.dart' show LabelEditorLocalizations;
import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:signers/routes.dart' show SignersLocalizations;
import 'package:silent/localizations.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mnemonic_entry/mnemonic_entry.dart';
import 'package:scanning/scanning.dart';

export 'package:bb_mobile/generated/l10n/localization.dart'
    show AppLocalizations, lookupAppLocalizations;

// Flutter's generated delegate list still names the SDK design libraries.
// Keep the app on the standalone delegates across automatic regeneration.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  TransactionsLocalizations.delegate,
  AccessLocalizations.delegate,
  ImportLocalizations.delegate,
  AnnouncementsLocalizations.delegate,
  BitcoinPriceLocalizations.delegate,
  ExchangeLocalizations.delegate,
  SignersLocalizations.delegate,
  SilentLocalizations.delegate,
  LabelEditorLocalizations.delegate,
  ScanningLocalizations.delegate,
  MnemonicEntryLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
