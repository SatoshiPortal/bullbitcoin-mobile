/// Whether [element] has the shape of one mnemonic word: non-empty, with
/// no whitespace anywhere in it.
///
/// bip39 joins a word list on the language separator and splits it straight
/// back, so it validates a sentence and never the element boundaries it was
/// handed. A list of twelve elements whose join is a valid fifteen-word
/// mnemonic passes its count, wordlist and checksum — and it is the list,
/// not the sentence, that gets stored, rendered and compared. This is the
/// one rule both the deriver and the storage model apply, each with its own
/// exception type: bip39's on the way in, the model's on the way out.
///
/// `\s` rather than the separator alone: bip39 NFKD-normalises every token,
/// and a generated mnemonic in any supported language carries no whitespace
/// inside a word — only between them.
bool isMnemonicWordShape(String element) =>
    element.isNotEmpty && !_whitespace.hasMatch(element);

final _whitespace = RegExp(r'\s');
