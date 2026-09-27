import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:secrets/src/widgets/painted_text.dart';
import 'package:secrets/src/public/extensions.dart';
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
/// The verdict is `secret.verify.mnemonic`, so the comparison that decides a
/// user's backup is the same one everywhere and is timed the same way.
///
/// No member hands out a word, and the tile word is painted (see
/// `PaintedWord`): a host walking its own element tree finds no text of the
/// mnemonic, so the per-tap order it could learn by tapping tiles itself is
/// an order of tiles it cannot read. What leaves is pixels — screenshot
/// blocking stays the host screen's job; the semantics tree is excluded here.
final class MnemonicChallenge extends StatefulWidget {
  final Secret secret;

  /// Renders one tile. Called during build, once per tile.
  final Widget Function(BuildContext context, MnemonicTile tile) tileBuilder;

  /// Arranges the rendered tiles. Receives widgets, not words.
  final Widget Function(BuildContext context, List<Widget> tiles) layoutBuilder;

  /// The user placed every word, and the sequence matched.
  final VoidCallback onSolved;

  /// A tap broke the order. The tiles have already been reshuffled and
  /// cleared: this is for the message, not for the reset.
  final VoidCallback onMistake;

  /// How many words the user has placed, out of how many. For the "what is word N" prompt — it says nothing about which words. A complete count precedes verification; only [onSolved] confirms success.
  final void Function(int placed, int total)? onProgress;

  /// Text style for the word inside each tile.
  final TextStyle? style;

  final Widget placeholder;

  /// Renders a read or verification failure. Calling retry clears the selection and reads the secret again; failures never count as mistakes.
  final Widget Function(BuildContext, SecretFailure, VoidCallback retry)
  failureBuilder;

  /// Built through `secret.widgets`; not for hosts to call.
  @internal
  const MnemonicChallenge({
    super.key,
    required this.secret,
    required this.tileBuilder,
    required this.layoutBuilder,
    required this.onSolved,
    required this.onMistake,
    required this.failureBuilder,
    this.onProgress,
    this.style,
    this.placeholder = const SizedBox.shrink(),
  });

  @override
  State<MnemonicChallenge> createState() => _MnemonicChallengeState();
}

final class _MnemonicChallengeState extends State<MnemonicChallenge> {
  late Future<Result<RevealedMnemonic, SecretFailure>> _revealed;
  int _generation = 0;
  bool _verifying = false;

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
    _startRead();
  }

  @override
  void didUpdateWidget(MnemonicChallenge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.secret.id != oldWidget.secret.id) {
      setState(_startRead);
    }
  }

  void _clear() {
    _answer = const [];
    _shuffled = const [];
    _placed.clear();
    _verifying = false;
  }

  void _startRead() {
    _clear();
    _revealed = _reveal(++_generation);
  }

  void _retry() {
    if (!mounted) return;
    setState(_startRead);
    widget.onProgress?.call(0, widget.secret.info.wordCount ?? 0);
  }

  /// Reads for the secret this widget holds *now*. The read outlives an
  /// `await`, and the widget may have been handed a different secret by then
  /// — so the result is kept only if it is still that secret's, and the
  /// widget is still mounted. Otherwise it is dropped: a stale read must not
  /// become the answer key for the secret on screen.
  Future<Result<RevealedMnemonic, SecretFailure>> _reveal(
    int generation,
  ) async {
    final id = widget.secret.id;
    final result = await widget.secret.revealMnemonic(
      reason: RevealReason.physicalBackupCheck,
    );
    if (!mounted || widget.secret.id != id || generation != _generation) {
      return result;
    }
    if (result case Ok(:final value)) {
      _answer = value.words;
      _shuffled = [...value.words]..shuffle();
      widget.onProgress?.call(0, _answer.length);
    }
    return result;
  }

  void _reshuffle() {
    _placed.clear();
    _verifying = false;
    _shuffled = [..._answer]..shuffle();
  }

  Future<void> _tap(int index) async {
    if (_answer.isEmpty ||
        index >= _shuffled.length ||
        _placed.contains(index) ||
        _verifying) {
      return;
    }
    final placed = [for (final i in _placed) _shuffled[i], _shuffled[index]];

    // The running check: a wrong word is caught on the tap, not at the end.
    // No early exit, like `verify.mnemonic`: one rule for comparing words, even
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

    setState(() {
      _placed.add(index);
      _verifying = placed.length == _answer.length;
    });
    widget.onProgress?.call(_placed.length, _answer.length);
    if (placed.length < _answer.length) return;

    // Complete: the verdict comes from the package's own comparison rather
    // than from the loop above, so what confirms a user's backup is the one
    // check the audit surface names. The secret is captured first: the
    // verdict is for *that* secret, and is reported only if the widget still
    // shows it once the read returns.
    final secret = widget.secret;
    final generation = _generation;
    final verdict = await secret.verify.mnemonic(placed);
    if (!mounted ||
        widget.secret.id != secret.id ||
        generation != _generation) {
      return;
    }
    switch (verdict) {
      case Ok(value: true):
        widget.onSolved();
      case Ok(value: false):
        setState(_reshuffle);
        widget.onProgress?.call(0, _answer.length);
        widget.onMistake();
      case Err(:final failure):
        final total = _answer.length;
        setState(() {
          _clear();
          _generation++;
          _revealed = Future.value(Err(failure));
        });
        widget.onProgress?.call(0, total);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Ok() => ExcludeSemantics(
            child: widget.layoutBuilder(context, [
              for (var i = 0; i < _shuffled.length; i++)
                widget.tileBuilder(
                  context,
                  MnemonicTile(
                    word: PaintedWord(_shuffled[i], style: widget.style),
                    isPlaced: _placed.contains(i),
                    position: _placed.contains(i)
                        ? _placed.indexOf(i) + 1
                        : null,
                    onTap: _placed.contains(i) || _verifying
                        ? null
                        : () => _tap(i),
                  ),
                ),
            ]),
          ),
        };
      },
    );
  }
}
