import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:secrets/src/widgets/painted_text.dart';
import 'package:secrets/src/public/secret.dart';

/// Shows a secret's words to the user without handing them to the caller.
///
/// The sealed-UI pattern (ARCHITECTURE.md, "Sealed UI as a security tool"): the mnemonic is read inside this widget's state and rendered here, so a feature can display it but cannot obtain it programmatically. This is why it lives in the package that holds the seed, and why the package depends on Flutter at all.
///
/// The words and the passphrase are painted (see `PaintedWord`), so a host walking its own element tree finds no text of them. What leaves is pixels: screenshot blocking and treating the screen as ephemeral remain the host screen's job; the semantics tree is excluded here, so accessibility services never read the words out.
///
/// Reads initially and on explicit retry with [RevealReason.userDisplay]; the read is logged by the package like any reveal. Rebuilding with the same secret does not trigger a new read.
final class MnemonicView extends StatefulWidget {
  final Secret secret;

  /// Text style for the words and the passphrase.
  final TextStyle? style;

  /// Shown above the passphrase when there is one. When `null`, a passphrase is shown without a label.
  final String? passphraseLabel;
  final TextStyle? passphraseLabelStyle;

  /// Rendered while the read is in flight.
  final Widget placeholder;

  /// Rendered when the read fails; receives the failure so the host can translate it and a callback to retry after unlocking the storage.
  final Widget Function(BuildContext, SecretFailure, VoidCallback retry)
  failureBuilder;

  /// Decorates one word. Called during this widget's build, once per word, with the word's 1-based number and the word **as a widget** — a `PaintedWord` whose text has no accessor. The host places it in a cell; it cannot read it, and a `Map<int, Widget>` reconstructs nothing. The text takes [style]. Default: the word alone.
  final Widget Function(BuildContext context, int number, Widget word)?
  wordBuilder;

  /// Arranges the rendered words. Receives **widgets**, not words, so a grid or a two-column layout costs the host nothing in exposure. Default with [wordBuilder]: a `Wrap`; without either: the words joined into one line, as before.
  final Widget Function(BuildContext context, List<Widget> words)?
  layoutBuilder;

  /// Built through `secret.widgets`; not for hosts to call.
  @internal
  const MnemonicView({
    super.key,
    required this.secret,
    required this.failureBuilder,
    this.style,
    this.passphraseLabel,
    this.passphraseLabelStyle,
    this.placeholder = const SizedBox.shrink(),
    this.wordBuilder,
    this.layoutBuilder,
  });

  @override
  State<MnemonicView> createState() => _MnemonicViewState();
}

/// A read, already painted. The state's future sits in a public framework field (`FutureBuilder.future`) that a host builder can reach through its `BuildContext`, so it never carries the words: only painted widgets, whose text has no accessor, in fields private to this library.
final class _Painted {
  final List<Widget> _words;
  final Widget _sentence;
  final Widget? _passphrase;

  _Painted(RevealedMnemonic mnemonic)
    : _words = [for (final word in mnemonic.words) PaintedWord(word)],
      _sentence = PaintedMnemonic(mnemonic.words),
      _passphrase = mnemonic.hasPassphrase
          ? PaintedPassphrase(mnemonic.passphrase)
          : null;
}

final class _MnemonicViewState extends State<MnemonicView> {
  late Future<Result<_Painted, SecretFailure>> _revealed;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _revealed = _reveal();
  }

  /// A state can be handed a different secret — a list that reorders without keys does exactly that. Showing the previous secret's words under the new one's fingerprint would be a leak across wallets, so the fingerprint is compared and the read redone. Host lists should still key each view by `secret.id`; this is the seatbelt for when they do not.
  @override
  void didUpdateWidget(MnemonicView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.secret.id != oldWidget.secret.id) {
      setState(() {
        _revealed = _reveal();
      });
    }
  }

  Future<Result<_Painted, SecretFailure>> _reveal() => widget.secret
      .revealMnemonic(reason: RevealReason.userDisplay)
      .then((result) => result.map(_Painted.new));

  void _retry() {
    if (!mounted) return;
    setState(() {
      _generation++;
      _revealed = _reveal();
    });
  }

  /// The host's layout, or the joined sentence when it supplied none.
  Widget _words(BuildContext context, _Painted painted) {
    final builder = widget.wordBuilder;
    final layout = widget.layoutBuilder;
    if (builder == null && layout == null) return painted._sentence;
    final cells = [
      for (var i = 0; i < painted._words.length; i++)
        builder?.call(context, i + 1, painted._words[i]) ?? painted._words[i],
    ];
    return layout?.call(context, cells) ?? Wrap(children: cells);
  }

  @override
  Widget build(BuildContext context) {
    // Keyed by fingerprint and read generation: a `FutureBuilder` keeps its last data while a new future is pending. A new key starts empty when changing secrets or retrying.
    return FutureBuilder(
      key: ValueKey((widget.secret.id.hex, _generation)),
      future: _revealed,
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result == null ||
            snapshot.connectionState != ConnectionState.done) {
          return widget.placeholder;
        }
        return switch (result) {
          Err(:final failure) => widget.failureBuilder(
            context,
            failure,
            _retry,
          ),
          // The painted widgets carry no style of their own: [style] reaches
          // them through the inherited text style.
          Ok(:final value) => ExcludeSemantics(
            child: DefaultTextStyle.merge(
              style: widget.style,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _words(context, value),
                  if (value._passphrase case final passphrase?) ...[
                    if (widget.passphraseLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          widget.passphraseLabel!,
                          style: widget.passphraseLabelStyle ?? widget.style,
                        ),
                      ),
                    passphrase,
                  ],
                ],
              ),
            ),
          ),
        };
      },
    );
  }
}
