import 'package:bb_mobile/_model/wallet.dart';
import 'package:flutter/material.dart';

class UIKeys {
  static const homeCardTestnet = Key('home_card_testnet');
  static const homeCardMainnet = Key('home_card_mainnet');
  static const homeSettingsButton = Key('settings_button');
  static const homeImportButton = Key('home_import_button');

  static const settingsBackButton = Key('settings_back_button');
  static const settingsTestnetSwitch = Key('testnet_switch');

  static const importImportButton = Key('import_import_button');
  static const importXpubField = Key('import_xpub_field');
  static const importXpubConfirmButton = Key('import_xpub_confirm_button');
  static const importWalletSelectionOption = Key('import_wallet_selection_option');
  static const importWalletSelectionSyncing = Key('import_wallet_selection_syncing');

  static const importRecoverScrollable = Key('import_recover_scrollable');

  static Key importRecoverField(int index) => Key('import_recover_field_$index');
  static const firstSuggestionWord = Key('first_suggestion_word');

  static const importRecoverButton = Key('import_recover_button');
  static const importRecoverConfirmButton = Key('import_recover_confirm_button');

  static Key importWalletSelectionCard(ScriptType type) =>
      Key('import_wallet_selection_option_${type.toString().split('.').last}');
  static const importWalletSelectionConfirmButton = Key('import_wallet_selection_confirm_button');
  static Key homeCardWithName(String name) => Key('home_card_with_name_$name');
}
