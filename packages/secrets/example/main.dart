// Example: consuming the `secrets` package as a library.
//
// One import, a one-time `Secrets.init(...)`, then static creation + a sealed
// `Secret` handle. Raw secret material never comes back — you get a handle, a
// non-secret result, or a sealed display widget.
import 'package:flutter/widgets.dart';
import 'package:secrets/secrets.dart';

/// The one contract the app provides: a non-secret index of which secrets exist.
/// The real app backs this with Drift; here it is a trivial in-memory map.
class InMemorySecretIndex implements SecretIndexPort {
  final _byFingerprint = <String, SecretInfo>{};

  @override
  Future<void> upsert(SecretInfo info) async =>
      _byFingerprint[info.fingerprint.hex] = info;

  @override
  Future<List<SecretInfo>> all() async => _byFingerprint.values.toList();

  @override
  Future<SecretInfo?> get(Fingerprint fp) async => _byFingerprint[fp.hex];

  @override
  Future<void> remove(Fingerprint fp) async => _byFingerprint.remove(fp.hex);
}

Future<void> main() async {
  // 1. Wire once at startup with the app's index (the OS keychain store is the
  //    default; pass `store:` to override for tests / a hardware backend).
  Secrets.init(index: InMemorySecretIndex());

  // 2. Import a mnemonic → a typed handle. The words are stored; they never
  //    come back out as data.
  final imported = await Secrets.importMnemonic(const [
    'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'abandon', //
    'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'about',
  ]);

  if (imported case Ok(value: final MnemonicSecret secret)) {
    // 3. Derive a watch-only descriptor (non-secret) off the handle — no
    //    fingerprint to re-pass, and a wrong-chain network won't compile.
    final descriptor = await secret.bitcoinDescriptor(
      scriptType: ScriptType.bip84,
      network: BitcoinNetwork.mainnet,
    );
    if (descriptor case Ok(value: final d)) {
      debugPrint('external descriptor: ${d.external}');
    }

    // 4. Fetch an existing secret later by its fingerprint; narrow to act on
    //    kind-specific metadata.
    final fetched = await Secrets.fetch(secret.fingerprint);
    if (fetched case Ok(value: final MnemonicSecret m)) {
      debugPrint('${m.wordCount} words · ${m.language}');
    }
  }
}

/// 5. Display the recovery phrase in a sealed widget — it renders the words on
///    screen (under a privacy guard) but never hands them to Dart code.
Widget recoveryPhraseScreen(Secret secret) => SecretRevealer(
      secret: secret,
      strings: const SecretRevealerStrings(
        unavailableMessage: 'Recovery phrase unavailable — unlock your device.',
        noPhraseMessage: 'This wallet has no recovery phrase.',
      ),
    );
