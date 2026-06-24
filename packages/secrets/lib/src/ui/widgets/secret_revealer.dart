import 'package:bull_ui/bull_ui.dart';
import 'package:meta/meta.dart';
import 'package:secrets/src/secrets_api.dart';
import 'package:secrets/src/ui/privacy_guard.dart';

/// Caller-supplied (localized) copy the [SecretRevealer] needs. The package
/// can't import the app's `AppLocalizations`, so the consumer passes the
/// localized strings in. There is intentionally NO `showPassphrase` flag — the
/// presence of a stored passphrase drives whether it is rendered.
@immutable
class SecretRevealerStrings {
  const SecretRevealerStrings({
    required this.unavailableMessage,
    required this.noPhraseMessage,
  });

  /// Shown when the secret can't be read right now — e.g. a locked keychain or
  /// a missing secret.
  final String unavailableMessage;

  /// Shown for a secret that has no recovery phrase to display (a bytes-only
  /// [SeedSecret], or an empty read).
  final String noPhraseMessage;
}

/// SEALED, polymorphic display of a stored [Secret]. Takes only the handle (no
/// words/bytes); reads the material internally and renders whatever the secret
/// naturally is — a mnemonic word grid (+ a passphrase row when one is stored),
/// or, once the seam lands, a bytes seed's hex. The material is never exposed
/// via a getter. Screen-capture-guarded, excluded from semantics, and redacted
/// in `debugFillProperties`.
class SecretRevealer extends StatefulWidget {
  const SecretRevealer({
    super.key,
    required this.secret,
    required this.strings,
  });

  /// Any kind of secret — the widget does all conditional rendering from it.
  final Secret secret;

  /// Localized labels only (the package can't localize).
  final SecretRevealerStrings strings;

  @override
  State<SecretRevealer> createState() => _SecretRevealerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    // Redacted: expose the public handle (fingerprint), NEVER the material.
    properties.add(StringProperty('fingerprint', secret.fingerprint.hex));
    properties.add(StringProperty('kind', secret.kind.name));
  }
}

class _SecretRevealerState extends State<SecretRevealer> {
  late Future<({List<String> words, String? passphrase})> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SecretRevealer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch if the parent swapped in a different secret — otherwise the old
    // secret's material would stay on screen (a stale-secret display bug).
    if (oldWidget.secret.fingerprint != widget.secret.fingerprint) {
      _load();
    }
  }

  void _load() {
    // Only a mnemonic-bearing secret is read. A SeedSecret renders its own
    // branch without the reader, so don't fire a (use-and-forget) read for it.
    if (widget.secret is! MnemonicSecret) {
      _future = Future.value((words: const <String>[], passphrase: null));
      return;
    }
    try {
      _future = Secrets.mnemonicReader.read(widget.secret.fingerprint);
    } catch (e) {
      // e.g. Secrets.init() was never called. Route to the FutureBuilder error
      // path (warning card) instead of crashing initState.
      _future = Future.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivacyGuard(
      child: switch (widget.secret) {
        MnemonicSecret() => _mnemonic(context),
        // DORMANT: there is no bytes-seed reader yet (the seed-import seam is
        // unbuilt). Until it lands, render the no-phrase copy rather than invent
        // a reader. When the seam exists this branch renders the hex view.
        SeedSecret() => BullSeedWarningCard(message: widget.strings.noPhraseMessage),
      },
    );
  }

  Widget _mnemonic(BuildContext context) {
    return FutureBuilder<({List<String> words, String? passphrase})>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          // A locked keychain / missing secret must surface, not spin forever.
          return BullSeedWarningCard(message: widget.strings.unavailableMessage);
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!;
        if (data.words.isEmpty) {
          // Nothing to show (e.g. a bytes-only stored secret) — no phrase.
          return BullSeedWarningCard(message: widget.strings.noPhraseMessage);
        }
        final passphrase = data.passphrase;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullMnemonicGrid(words: data.words),
              if (passphrase != null && passphrase.isNotEmpty) ...[
                const Gap(BullSpacing.md),
                BullText(
                  passphrase,
                  style: Theme.of(context).textTheme.bodyLarge,
                  color: context.bull.onSurface,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
