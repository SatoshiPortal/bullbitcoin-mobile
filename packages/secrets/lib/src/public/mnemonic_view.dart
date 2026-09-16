import 'package:flutter/widgets.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:secrets/src/public/sealed_word.dart';
import 'package:secrets/src/public/secret.dart';

/// Shows a secret's words to the user without handing them to the caller.
///
/// The sealed-UI pattern (ARCHITECTURE.md, "Sealed UI as a security tool"): the mnemonic is read inside this widget's state and rendered here, so a feature can display it but cannot obtain it programmatically. This is why it lives in the package that holds the seed, and why the package depends on Flutter at all.
///
/// The seal covers API leakage only. Screenshot blocking and treating the screen as ephemeral remain the host screen's job; the semantics tree is excluded here, so accessibility services never read the words out.
///
/// Reads once, on first build, with [RevealReason.userDisplay]; the read is logged by the package like any reveal.
final class MnemonicView extends StatefulWidget {
  final Secret secret;

  /// Text style for the words and the passphrase.
  final TextStyle? style;

  /// Shown above the passphrase when there is one. When `null`, a passphrase is shown without a label.
  final String? passphraseLabel;
  final TextStyle? passphraseLabelStyle;

  /// Rendered while the read is in flight.
  final Widget placeholder;

  /// Rendered when the read fails; receives the failure so the host can translate it.
  final Widget Function(BuildContext, SecretFailure) onFailure;

  /// Decorates one word. Called during this widget's build, once per word, with the word's 1-based number and the word **as a widget** — a `SealedWord` whose text has no accessor. The host places it in a cell; it cannot read it, and a `Map<int, Widget>` reconstructs nothing. The text takes [style]. Default: the word alone.
  final Widget Function(BuildContext context, int number, Widget word)?
  wordBuilder;

  /// Arranges the rendered words. Receives **widgets**, not words, so a grid or a two-column layout costs the host nothing in exposure. Default with [wordBuilder]: a `Wrap`; without either: the words joined into one line, as before.
  final Widget Function(BuildContext context, List<Widget> words)? layout;

  const MnemonicView({
    super.key,
    required this.secret,
    required this.onFailure,
    this.style,
    this.passphraseLabel,
    this.passphraseLabelStyle,
    this.placeholder = const SizedBox.shrink(),
    this.wordBuilder,
    this.layout,
  });

  @override
  State<MnemonicView> createState() => _MnemonicViewState();
}

final class _MnemonicViewState extends State<MnemonicView> {
  late Future<Result<RevealedMnemonic, SecretFailure>> _revealed;

  @override
  void initState() {
    super.initState();
    _revealed = _reveal();
  }

  /// A state can be handed a different secret — a list that reorders without keys does exactly that. Showing the previous secret's words under the new one's identity would be a leak across wallets, so the identity is compared and the read redone. Host lists should still key each view by `secret.id`; this is the seatbelt for when they do not.
  @override
  void didUpdateWidget(MnemonicView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.secret.id != oldWidget.secret.id) {
      setState(() {
        _revealed = _reveal();
      });
    }
  }

  Future<Result<RevealedMnemonic, SecretFailure>> _reveal() =>
      widget.secret.revealWords(reason: RevealReason.userDisplay);

  /// The host's layout, or the joined sentence when it supplied none.
  Widget _words(BuildContext context, List<String> words) {
    final builder = widget.wordBuilder;
    final layout = widget.layout;
    if (builder == null && layout == null) {
      return Text(words.join(' '), style: widget.style);
    }
    final cells = [
      for (var i = 0; i < words.length; i++)
        builder?.call(
              context,
              i + 1,
              SealedWord(words[i], style: widget.style),
            ) ??
            SealedWord(words[i], style: widget.style),
    ];
    return layout?.call(context, cells) ?? Wrap(children: cells);
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      // Keyed by identity: a `FutureBuilder` keeps its last data while a new future is pending, which would leave the previous secret's words on screen. A new key is a new element, starting empty.
      child: FutureBuilder(
        key: ValueKey(widget.secret.id.hex),
        future: _revealed,
        builder: (context, snapshot) {
          final result = snapshot.data;
          if (result == null ||
              snapshot.connectionState != ConnectionState.done) {
            return widget.placeholder;
          }
          return switch (result) {
            Err(:final failure) => widget.onFailure(context, failure),
            Ok(:final value) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _words(context, value.words),
                if (value.hasPassphrase) ...[
                  if (widget.passphraseLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        widget.passphraseLabel!,
                        style: widget.passphraseLabelStyle ?? widget.style,
                      ),
                    ),
                  Text(value.passphrase, style: widget.style),
                ],
              ],
            ),
          };
        },
      ),
    );
  }
}
