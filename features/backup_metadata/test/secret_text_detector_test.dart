import 'package:backup_metadata/src/domain/content_sanitizer.dart';
import 'package:backup_metadata/src/domain/entities/backup_content.dart';
import 'package:backup_metadata/src/domain/secret_text_detector.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language, Mnemonic;
import 'package:flutter_test/flutter_test.dart';
import 'package:labels/backup.dart';
import 'package:unorm_dart/unorm_dart.dart' show nfc, nfd;
import 'package:primitives/primitives.dart';

const _phrase =
    'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';
// Public BIP32 test vector 1 (never funded): an extended private key.
const _xprv =
    'xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi';
const _xpub =
    'xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8';
// The wiki's example private key in WIF (uncompressed, mainnet).
const _wif = '5HueCGU8rMjxEXxiPuD5BDku4MkFqeZyd4dZ1jvhTVqvbTLvyTJ';

void main() {
  group('the detector', () {
    test('flags a phrase-shaped run of twelve BIP39 words, in any dress', () {
      expect(looksLikeSecretMaterial(_phrase), isTrue);
      expect(looksLikeSecretMaterial(_phrase.toUpperCase()), isTrue);
      expect(
        looksLikeSecretMaterial('seed: ${_phrase.replaceAll(' ', ', ')}.'),
        isTrue,
      );
      expect(looksLikeSecretMaterial('rent for $_phrase last month'), isTrue);
      expect(looksLikeSecretMaterial(_phrase.replaceAll(' ', '\n')), isTrue);
    });

    test('lets ordinary notes through', () {
      expect(looksLikeSecretMaterial('Rent for October'), isFalse);
      expect(looksLikeSecretMaterial(''), isFalse);
      // Eleven words, however BIP39-looking.
      expect(
        looksLikeSecretMaterial(
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon',
        ),
        isFalse,
      );
      // Twelve words, one of them not on the list: a sentence, not a phrase.
      expect(
        looksLikeSecretMaterial(
          'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon bitcoinzzz',
        ),
        isFalse,
      );
      // A run broken by a number is two short runs.
      expect(
        looksLikeSecretMaterial(
          'abandon abandon abandon abandon abandon abandon 7 '
          'abandon abandon abandon abandon abandon about',
        ),
        isFalse,
      );
    });

    test('flags extended private keys and WIF keys, never public keys', () {
      expect(looksLikeSecretMaterial(_xprv), isTrue);
      expect(looksLikeSecretMaterial('key $_xprv saved'), isTrue);
      expect(looksLikeSecretMaterial(_wif), isTrue);
      expect(looksLikeSecretMaterial(_xpub), isFalse);
      expect(looksLikeSecretMaterial('a'.padRight(51, 'b')), isFalse);
    });
  });

  group('the sanitizer', () {
    BackupWallet wallet(String? label) => BackupWallet(
      walletId: 'w',
      network: BitcoinNetwork.testnet,
      scriptType: ScriptType.bip84,
      externalDescriptor: 'wpkh(external)',
      internalDescriptor: 'wpkh(internal)',
      watchOnly: false,
      label: label,
    );

    BackupContent content({
      List<BackupLabelRecord> records = const [],
      String? walletName = 'Savings',
      String? alias = 'child',
    }) => BackupContent(
      labels: LabelsSnapshot(
        records: records,
        unattributedCount: 0,
        skippedCount: 0,
      ),
      wallets: [wallet(walletName)],
      derivations: [
        BackupDerivation(
          path: "128169'/32'/0'",
          application: 'hex',
          status: 'active',
          alias: alias,
        ),
      ],
    );

    test('excludes a label record whose text is a phrase', () {
      final clean = sanitizeContent(
        content(
          records: [
            BackupLabelRecord(
              chain: BackupLabelChain.bitcoin,
              type: BackupLabelType.tx,
              ref: 'aa' * 32,
              label: _phrase,
            ),
            BackupLabelRecord(
              chain: BackupLabelChain.bitcoin,
              type: BackupLabelType.tx,
              ref: 'bb' * 32,
              label: 'rent',
            ),
          ],
        ),
      );
      expect(clean.excluded, 1);
      expect(clean.labels.records.map((record) => record.label), ['rent']);
    });

    test('a frozen coin keeps its freeze and loses its text', () {
      final clean = sanitizeContent(
        content(
          records: [
            BackupLabelRecord(
              chain: BackupLabelChain.bitcoin,
              type: BackupLabelType.output,
              ref: '${'cc' * 32}:0',
              label: _xprv,
              spendable: false,
              walletId: 'w',
            ),
          ],
        ),
      );
      expect(clean.excluded, 1);
      expect(clean.labels.records.single.spendable, isFalse);
      expect(clean.labels.records.single.label, isNull);
    });

    test('a wallet name is blanked, its account stays', () {
      final clean = sanitizeContent(content(walletName: _wif));
      expect(clean.excluded, 1);
      expect(clean.wallets.single.label, isNull);
      expect(clean.wallets.single.externalDescriptor, 'wpkh(external)');
    });

    test('a BIP85 alias is blanked, its child stays in the registry', () {
      final clean = sanitizeContent(content(alias: _phrase));
      expect(clean.excluded, 1);
      expect(clean.derivations.single.alias, isNull);
      expect(clean.derivations.single.path, "128169'/32'/0'");
    });

    test('clean content is returned untouched', () {
      final original = content();
      expect(identical(sanitizeContent(original), original), isTrue);
      expect(original.excluded, 0);
    });
  });

  group('every BIP39 language', () {
    for (final language in Language.values) {
      test('${language.label}: a phrase of twelve words is flagged', () {
        final words = language.list.take(12).toList();
        final phrase = words.join(language.separator);
        expect(looksLikeSecretMaterial(phrase), isTrue);
        expect(looksLikeSecretMaterial('note: $phrase.'), isTrue);
        // The ordinary separators work too, whatever the language.
        expect(looksLikeSecretMaterial(words.join(' ')), isTrue);
        expect(looksLikeSecretMaterial(words.join('\n')), isTrue);
        // Eleven words are only a few words.
        expect(
          looksLikeSecretMaterial(words.take(11).join(language.separator)),
          isFalse,
        );
      });
    }

    test(
      'composed, decomposed and capitalized spellings are flagged alike',
      () {
        for (final language in Language.values) {
          final words = language.list.take(12).toList();
          for (final spelling in [nfc, nfd]) {
            final phrase = words.map(spelling).join(language.separator);
            expect(
              looksLikeSecretMaterial(phrase),
              isTrue,
              reason: '${language.label} ${spelling == nfc ? 'NFC' : 'NFD'}',
            );
          }
          expect(
            looksLikeSecretMaterial(
              words.map((w) => w.toUpperCase()).join(language.separator),
            ),
            isTrue,
            reason: '${language.label} uppercase',
          );
        }
      },
    );

    test('ordinary accented and non-Latin notes are not flagged', () {
      for (final note in [
        'Loyer d\u2019octobre : \u00e9lectricit\u00e9 et caf\u00e9 \u00e0 la fois',
        '\u00c9pargne pour l\u2019\u00e9t\u00e9, \u00e0 d\u00e9penser avec soin',
        '\u5bb6\u8cc3\u300110\u6708\u5206\u3001\u96fb\u6c17\u4ee3\u3092\u542b\u3080',
        '\u3053\u306e\u30b3\u30a4\u30f3\u306f\u7d30\u304b\u3044\u652f\u6255\u3044\u7528\u3067\u3059',
        '\u623f\u79df \u5341\u6708 \u7535\u8d39 \u548c \u8d2d\u7269 \u8d26\u5355',
        '\u623f\u79df\u5341\u6708\u7535\u8d39\u548c\u8d2d\u7269\u8d26\u5355\u8bb0\u5f55',
      ]) {
        expect(looksLikeSecretMaterial(note), isFalse, reason: note);
      }
    });
  });

  test('a reference carrying secret material excludes its record', () {
    BackupLabelRecord record(String ref, {bool freeze = false}) =>
        BackupLabelRecord(
          chain: BackupLabelChain.bitcoin,
          type: freeze ? BackupLabelType.output : BackupLabelType.addr,
          ref: ref,
          label: freeze ? null : 'fine',
          spendable: freeze ? false : null,
          walletId: freeze ? 'w' : null,
        );
    final clean = sanitizeContent(
      BackupContent(
        labels: LabelsSnapshot(
          records: [
            record('bc1qsomeaddress $_phrase'),
            record('$_phrase:0', freeze: true),
            record('bc1qordinaryaddress'),
          ],
          unattributedCount: 0,
          skippedCount: 0,
        ),
        wallets: const [],
        derivations: const [],
      ),
    );
    // Even a freeze goes: its reference is what carries the secret, and the
    // reference cannot be blanked.
    expect(clean.labels.records.map((r) => r.ref), ['bc1qordinaryaddress']);
    expect(clean.excluded, 2);
  });

  test('counts each detected text field and preserves the freeze', () {
    final clean = sanitizeContent(
      BackupContent(
        labels: LabelsSnapshot(
          records: [
            BackupLabelRecord(
              chain: BackupLabelChain.bitcoin,
              type: BackupLabelType.output,
              ref: '${'bb' * 32}:1',
              label: _phrase,
              origin: _phrase,
              spendable: false,
              walletId: 'w',
            ),
          ],
          unattributedCount: 0,
          skippedCount: 0,
        ),
        wallets: const [],
        derivations: const [],
      ),
    );
    expect(clean.excluded, 2);
    expect(clean.labels.records.single.spendable, isFalse);
    expect(clean.labels.records.single.walletId, 'w');
    expect(clean.labels.records.single.label, isNull);
    expect(clean.labels.records.single.origin, isNull);
  });

  group('Chinese phrases written without separators', () {
    for (final language in [
      Language.simplifiedChinese,
      Language.traditionalChinese,
    ]) {
      test('${language.label}: twelve contiguous characters are flagged', () {
        final words = Mnemonic(List.filled(16, 0), language).words;
        expect(looksLikeSecretMaterial(words.join()), isTrue);
        expect(looksLikeSecretMaterial('备注：${words.join()}。'), isTrue);
        expect(looksLikeSecretMaterial(words.take(11).join()), isFalse);
        // A character outside the list breaks the run.
        expect(
          looksLikeSecretMaterial(
            '${words.take(6).join()}\u9f98${words.skip(6).join()}',
          ),
          isFalse,
        );
      });
    }

    test('ordinary text can collide with a valid Chinese checksum', () {
      const note = '我今天有一点时间和你出去';
      expect(
        () => Mnemonic.fromWords(
          words: note.runes.map(String.fromCharCode).toList(),
          language: Language.simplifiedChinese,
        ),
        returnsNormally,
      );
      expect(looksLikeSecretMaterial(note), isTrue);
    });

    for (final note in [
      '我们明天一起出去吃饭好吗',
      '\u623f\u79df\u5341\u6708\u7535\u8d39\u548c\u8d2d\u7269\u8d26\u5355\u8bb0\u5f55',
      '\u4eca\u5929\u5728\u5e02\u573a\u4e70\u4e86\u4e09\u65a4\u82f9\u679c\u548c\u4e24\u6761\u9c7c\uff0c\u82b1\u4e86\u4e8c\u5341\u4e94\u5143\u3002',
      '\u9910\u5385\u665a\u9910\u5206\u644a\u8d26\u5355\uff0c\u5171\u56db\u4eba\uff0c\u6bcf\u4eba\u4ed8\u4e00\u767e\u5143\u3002',
      '\u5bb6\u7528\u7535\u5668\u7ef4\u4fee\u8d39\u7528\u4ee5\u53ca\u8fd0\u8d39\u5171\u8ba1\u4e00\u5343\u5143',
    ]) {
      test('ordinary Chinese text is not flagged: $note', () {
        expect(looksLikeSecretMaterial(note), isFalse, reason: note);
      });
    }
  });
}
