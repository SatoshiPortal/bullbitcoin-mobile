import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

typedef Mnemonic = ({
  String label,
  String passphrase,
  List<String> words,
  bip39.Language language,
});
