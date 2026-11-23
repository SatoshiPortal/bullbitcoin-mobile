import 'package:wallet_import/src/domain/bip39_word_list.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:unorm_dart/unorm_dart.dart';

/// The keys the mnemonic keyboard shows for one wordlist, every value in the
/// NFKD form the matcher compares.
///
/// An alphabetic wordlist gets the national layout of its language, its
/// other letters on an accent page; any other script gets a grid of the
/// characters that can come next, computed per keystroke by the owner.
class MnemonicKeyboardLayout {
  /// The letter keys in display order, empty for a grid.
  final List<String> keys;

  /// Key count of each letter row.
  final List<int> rows;

  /// The wordlist's letters missing from the layout: the accent page.
  final List<String> accents;

  /// Other scripts are typed on a grid of possible characters.
  final bool grid;

  const MnemonicKeyboardLayout._({
    required this.keys,
    required this.rows,
    required this.accents,
    required this.grid,
  });

  static final _cache = <bip39.Language, MnemonicKeyboardLayout>{};

  static MnemonicKeyboardLayout of(bip39.Language language) =>
      _cache[language] ??= _build(language);

  static const _qwerty = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];
  static const _azerty = ['azertyuiop', 'qsdfghjklm', 'wxcvbn'];
  static const _qwertz = ['qwertzuiop', 'asdfghjkl', 'yxcvbnm'];

  /// Spanish keeps ñ at the end of the second row, as Spanish keyboards do.
  static const _spanish = ['qwertyuiop', 'asdfghjklñ', 'zxcvbnm'];

  /// The national default of each alphabetic wordlist.
  static List<String>? _rowsOf(bip39.Language language) => switch (language) {
    bip39.Language.english ||
    bip39.Language.italian ||
    bip39.Language.portuguese => _qwerty,
    bip39.Language.french => _azerty,
    bip39.Language.spanish => _spanish,
    bip39.Language.czech => _qwertz,
    _ => null,
  };

  static MnemonicKeyboardLayout _build(bip39.Language language) {
    final rows = _rowsOf(language);
    if (rows == null || !Bip39WordList.isAlphabetic(language)) {
      return const MnemonicKeyboardLayout._(
        keys: [],
        rows: [],
        accents: [],
        grid: true,
      );
    }
    final keys = [for (final row in rows) ...row.split('').map(nfkd)];
    return MnemonicKeyboardLayout._(
      keys: keys,
      rows: [for (final row in rows) row.length],
      accents: Bip39WordList.accentedLetters(language)
          .where((letter) => !keys.contains(letter))
          .toList(),
      grid: false,
    );
  }

  /// The accents a long press on each base letter offers: those of
  /// [accents] (in their current order) that [allowed] lets extend the word.
  static Map<String, List<String>> variantsOf({
    required List<String> accents,
    required Set<String> allowed,
  }) {
    final variants = <String, List<String>>{};
    for (final accent in accents) {
      if (!allowed.contains(accent)) continue;
      (variants[accent[0]] ??= []).add(accent);
    }
    return variants;
  }
}
