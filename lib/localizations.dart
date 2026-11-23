import 'package:access/setup.dart' show AccessLocalizations;
import 'package:bitcoin_price/bitcoin_price.dart'
    show BitcoinPriceLocalizations;
import 'package:announcements/announcements.dart'
    show AnnouncementsLocalizations;
import 'package:label_editor/label_editor.dart' show LabelEditorLocalizations;
import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:signers/routes.dart' show SignersLocalizations;
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mnemonic_entry/mnemonic_entry.dart';
import 'package:scanning/scanning.dart';

export 'package:bb_mobile/generated/l10n/localization.dart'
    show AppLocalizations, lookupAppLocalizations;

extension ScanningLocalization on AppLocalizations {
  QrScanningLabels get qrScanning => (
    scanningProgressLabel: scanningProgressLabel,
    urProgressLabel: urProgressLabel,
    scanningCompletedMessage: scanningCompletedMessage,
    urDecodingFailedMessage: urDecodingFailedMessage,
    urProcessingFailedMessage: urProcessingFailedMessage,
  );

  NfcScanningLabels get nfcScanning => (
    scanNfcButton: scanNfcButton,
    nfcConnectionLost: nfcConnectionLost,
    nfcWriteFailed: nfcWriteFailed,
    nfcDisabled: nfcDisabled,
    nfcNotAvailable: nfcNotAvailable,
    nfcFailed: oopsSomethingWentWrong,
    nfcInvalidData: nfcInvalidData,
  );
}

extension MnemonicEntryLocalization on AppLocalizations {
  MnemonicEntryLabels get mnemonicEntry => (
    mnemonicWordCountLabel: mnemonicWordCountLabel,
    mnemonicLanguageAmbiguous: mnemonicLanguageAmbiguous,
    mnemonicLanguageSuggestion: mnemonicLanguageSuggestion,
    mnemonicLanguageName: mnemonicLanguageName,
    passphraseOption: passphraseOption,
    passphraseOptionOnSubtitle: passphraseOptionOnSubtitle,
    passphraseOptionOffSubtitle: passphraseOptionOffSubtitle,
    passphraseLabel: passphraseLabel,
    optionalPassphraseHint: optionalPassphraseHint,
    passphraseShow: passphraseShow,
    passphraseHide: passphraseHide,
    passphraseClearedNotice: passphraseClearedNotice,
    continueWithoutPassphrase: continueWithoutPassphrase,
    passphraseWhitespaceWarning: passphraseWhitespaceWarning,
    recipientsInfoLabel: recipientsInfoLabel,
    requiredHint: requiredHint,
    submitButton: submitButton,
    mnemonicShuffleKeyboardHint: mnemonicShuffleKeyboardHint,
    mnemonicLanguageLabel: mnemonicLanguageLabel,
    mnemonicPossibleLastWords: mnemonicPossibleLastWords,
    emptyMnemonicWordsError: emptyMnemonicWordsError,
    mnemonicInvalidChecksumError: mnemonicInvalidChecksumError,
    mnemonicUnknownWordError: mnemonicUnknownWordError,
    mnemonicOtherLanguageWordsError: mnemonicOtherLanguageWordsError,
    oopsSomethingWentWrong: oopsSomethingWentWrong,
  );
}

// Flutter's generated delegate list still names the SDK design libraries.
// Keep the app on the standalone delegates across automatic regeneration.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  AccessLocalizations.delegate,
  AnnouncementsLocalizations.delegate,
  BitcoinPriceLocalizations.delegate,
  ExchangeLocalizations.delegate,
  SignersLocalizations.delegate,
  LabelEditorLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
