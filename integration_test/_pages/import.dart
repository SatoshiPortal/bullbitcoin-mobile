import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:flutter_test/flutter_test.dart';

class TImportPage {
  Finder get importButton => find.byKey(UIKeys.importImportButton);
  Finder get xpubField => find.byKey(UIKeys.importXpubField);
  Finder get xpubConfirmButton => find.byKey(UIKeys.importXpubConfirmButton);
  Finder get walletSelectionOption => find.byKey(UIKeys.importWalletSelectionOption);
  Finder get walletSelectionSyncing => find.byKey(UIKeys.importWalletSelectionSyncing);
  Finder get recoverButton => find.byKey(UIKeys.importRecoverButton);
  Finder get walletSelectionConfirmButton => find.byKey(UIKeys.importWalletSelectionConfirmButton);
  Finder importRecoverField(int index) => find.byKey(UIKeys.importRecoverField(index));
  Finder importWalletSelectionCard(ScriptType type) =>
      find.byKey(UIKeys.importWalletSelectionCard(type));
  Finder homeCardWithName(String name) => find.byKey(UIKeys.homeCardWithName(name));
}
