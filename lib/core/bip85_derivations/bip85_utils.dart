import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

class Bip85Utils {
  static int bip39LengthToBip85Code(bip39.MnemonicLength length) {
    switch (length) {
      case bip39.MnemonicLength.words12:
        return 12;
      case bip39.MnemonicLength.words15:
        return 15;
      case bip39.MnemonicLength.words18:
        return 18;
      case bip39.MnemonicLength.words21:
        return 21;
      case bip39.MnemonicLength.words24:
        return 24;
    }
  }

  static int bip39LanguageToBip85Code(bip39.Language language) {
    switch (language) {
      case bip39.Language.english:
        return 0;
      case bip39.Language.japanese:
        return 1;
      case bip39.Language.korean:
        return 2;
      case bip39.Language.spanish:
        return 3;
      case bip39.Language.simplifiedChinese:
        return 4;
      case bip39.Language.traditionalChinese:
        return 5;
      case bip39.Language.french:
        return 6;
      case bip39.Language.italian:
        return 7;
      case bip39.Language.czech:
        return 8;
      case bip39.Language.portuguese:
        return 9;
    }
  }
}
