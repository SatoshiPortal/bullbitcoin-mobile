import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';

class TImportPage {
  TImportPage({required this.tester});

  final WidgetTester tester;

  Finder get importButton => find.byKey(UIKeys.importImportButton);
  Finder get xpubField => find.byKey(UIKeys.importXpubField);
  Finder get xpubConfirmButton => find.byKey(UIKeys.importXpubConfirmButton);
  Finder get recoverButton => find.byKey(UIKeys.importRecoverButton);
  Finder get walletSelectionConfirmButton => find.byKey(UIKeys.importWalletSelectionConfirmButton);
  Finder importRecoverField(int index) => find.byKey(UIKeys.importRecoverField(index));
  Finder get importRecoverScrollable => find.byKey(UIKeys.importRecoverScrollable);
  Finder get importRecoverConfirmButton => find.byKey(UIKeys.importRecoverConfirmButton);
  Finder importWalletSelectionCard(ScriptType type) =>
      find.byKey(UIKeys.importWalletSelectionCard(type));
  Finder get walletSelectionOption => find.byKey(UIKeys.importWalletSelectionOption);
  Finder get walletSelectionSyncing => find.byKey(UIKeys.importWalletSelectionSyncing);
  Finder homeCardWithName(String name) => find.byKey(UIKeys.homeCardWithName(name));
  Finder firstSuggestionWord = find.byKey(UIKeys.firstSuggestionWord);

  Future tapImportButton() async {
    await tester.tap(importButton);
    await tester.pumpAndSettle();
  }

  Future tapRecoverButton() async {
    await tester.tap(recoverButton);
    await tester.pumpAndSettle();
  }

  Future tapFirstSuggestionWord() {
    return tester.tap(firstSuggestionWord);
  }

  Future enterWordsIntoFields(
    List<String> words,
  ) async {
    for (var i = 0; i < words.length; i++) {
      await tester.enterText(importRecoverField(i), words[i]);
      await Future.delayed(200.ms);
      await tapFirstSuggestionWord();
      await Future.delayed(200.ms);
    }
  }

  Future tapRecoverConfirmButton() async {
    await tester.tap(importRecoverConfirmButton);
    await tester.pumpAndSettle();
  }

  Future scrollToBottom() async {
    await tester.drag(importRecoverScrollable, const Offset(0, -500));
    await tester.pumpAndSettle();
  }

  Future waitForWalletsToSync() async {
    await tester.pumpAndSettle();
  }

  Future selectWalletWithMostTxs() async {
    await tester.pumpAndSettle();
  }

  Future tapWalletSelectionConfirmButton() async {
    await tester.pumpAndSettle();
  }
}
