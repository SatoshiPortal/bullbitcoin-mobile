import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:secrets/src/widgets/sealed_word.dart';
import 'package:secrets/src/public/secret.dart';

/// One tile in a [MnemonicChallenge]: a word to tap, and where it stands.
///
/// A value the host styles. [word] is a widget whose text has no accessor,
/// so the tiles a host is handed do not add up to the mnemonic — not as a
/// list, and not as a `Map<int, Widget>` either.
final class MnemonicTile {
  /// The word, as a widget to place. Never the string.
  final Widget word;

  /// Whether the user has already placed this tile.
  final bool isPlaced;

  /// The 1-based position the user gave it, or `null` while unplaced.
  final int? position;

  /// `null` once placed: a tile is tapped at most once.
  final VoidCallback? onTap;

  /// Built through `secret.widgets`; not for hosts to call.
  @internal
  const MnemonicTile({
    required this.word,
    required this.isPlaced,
    required this.position,
    required this.onTap,
  });
}

/// The "tap your words in order" backup check, sealed.
///
/// The sealed-UI pattern, like [MnemonicView], for the screen that is harder
/// to seal: the words must be on screen *and* in an order only the widget
/// knows. So the shuffle, the running comparison and the verdict all happen
/// in here — the host receives one [MnemonicTile] at a time and arranges
/// widgets. It never holds the mnemonic, in state or anywhere else.
///
/// The verdict is [Secret.verifyWords], so the comparison that decides a
/// user's backup is the same one everywhere and is timed the same way.
///
/// The seal covers API leakage only: no member hands out a word, and the tile
/// text has no accessor. A host that walks its own element tree can still
/// read the inner `Text` — that is a deliberate act, and reads as one in
/// review. Screenshot blocking stays the host screen's job; the semantics
/// tree is excluded here.
final class MnemonicChallenge extends StatefulWidget {
  final Secret secret;

  /// Renders one tile. Called during build, once per tile.
  final Widget Function(BuildContext context, MnemonicTile tile) tileBuilder;

  /// Arranges the rendered tiles. Receives widgets, not words.
  final Widget Function(BuildContext context, List<Widget> tiles) layout;

  /// The user placed every word, and the sequence matched.
  final VoidCallback onSolved;

  /// A tap broke the order. The tiles have already been reshuffled and
  /// cleared: this is for the message, not for the reset.
  final VoidCallback onMistake;

  /// How many words the user has placed, out of how many. For the "what is
  /// word N" prompt — it says nothing about which words.
  final void Function(int placed, int total)? onProgress;

  /// Text style for the word inside each tile.
  final TextStyle? style;

  final Widget placeholder;
  final Widget Function(BuildContext, SecretFailure) onFailure;

  /// Built through `secret.widgets`; not for hosts to call.
  @internal
  const MnemonicChallenge({
    super.key,
    required this.secret,
    required this.tileBuilder,
    required this.layout,
    required this.onSolved,
    required this.onMistake,
    required this.onFailure,
    this.onProgress,
    this.style,
    this.placeholder = const SizedBox.shrink(),
  });

  @override
  State<MnemonicChallenge> createState() => _MnemonicChallengeState();
}

final class _MnemonicChallengeState extends State<MnemonicChallenge> {
  late Future<Result<RevealedMnemonic, SecretFailure>> _revealed;

  /// The words in the order the user sees them. Rebuilt on every mistake.
  List<String> _shuffled = const [];

  /// Indices into [_shuffled], in the order the user tapped them.
  final _placed = <int>[];

  /// The stored order, for the running prefix check. Held here and nowhere
  /// else: this state is discarded with the screen.
  List<String> _answer = const [];

  @override
  void initState() {
    super.initState();
    _revealed = _reveal();
  }

  @override
  void didUpdateWidget(MnemonicChallenge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.secret.id != oldWidget.secret.id) {
      setState(() {
        _answer = const [];
        _shuffled = const [];
        _placed.clear();
        _revealed = _reveal();
      });
    }
  }

  /// Reads for the secret this widget holds *now*. The read outlives an
  /// `await`, and the widget may have been handed a different secret by then
  /// — so the result is kept only if it is still that secret's, and the
  /// widget is still mounted. Otherwise it is dropped: a stale read must not
  /// become the answer key for the secret on screen.
  Future<Result<RevealedMnemonic, SecretFailure>> _reveal() async {
    final id = widget.secret.id;
    final result = await widget.secret.revealMnemonic(
      reason: RevealReason.physicalBackupCheck,
    );
    if (!mounted || widget.secret.id != id) return result;
    if (result case Ok(:final value)) {
      _answer = value.words;
      _shuffled = [...value.words]..shuffle();
    }
    return result;
  }

  void _reshuffle() {
    _placed.clear();
    _shuffled = [..._answer]..shuffle();
  }

  Future<void> _tap(int index) async {
    if (_answer.isEmpty || index >= _shuffled.length) return;
    final placed = [for (final i in _placed) _shuffled[i], _shuffled[index]];

    // The running check: a wrong word is caught on the tap, not at the end.
    // No early exit, like `verifyWords`: one rule for comparing words, even
    // where the only observer of the timing is the user.
    var correctSoFar = true;
    for (var i = 0; i < placed.length; i++) {
      if (_answer[i] != placed[i]) correctSoFar = false;
    }
    if (!correctSoFar) {
      setState(_reshuffle);
      widget.onProgress?.call(0, _answer.length);
      widget.onMistake();
      return;
    }

    setState(() => _placed.add(index));
    widget.onProgress?.call(_placed.length, _answer.length);
    if (placed.length < _answer.length) return;

    // Complete: the verdict comes from the package's own comparison rather
    // than from the loop above, so what confirms a user's backup is the one
    // check the audit surface names. The secret is captured first: the
    // verdict is for *that* secret, and is reported only if the widget still
    // shows it once the read returns.
    final secret = widget.secret;
    final verdict = await secret.verifyWords(placed);
    if (!mounted || widget.secret.id != secret.id) return;
    switch (verdict) {
      case Ok(value: true):
        widget.onSolved();
      case Ok(value: false):
      case Err():
        setState(_reshuffle);
        widget.onProgress?.call(0, _answer.length);
        widget.onMistake();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
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
            Ok() => widget.layout(context, [
              for (var i = 0; i < _shuffled.length; i++)
                widget.tileBuilder(
                  context,
                  MnemonicTile(
                    word: SealedWord(_shuffled[i], style: widget.style),
                    isPlaced: _placed.contains(i),
                    position: _placed.contains(i)
                        ? _placed.indexOf(i) + 1
                        : null,
                    onTap: _placed.contains(i) ? null : () => _tap(i),
                  ),
                ),
            ]),
          };
        },
      ),
    );
  }
}
