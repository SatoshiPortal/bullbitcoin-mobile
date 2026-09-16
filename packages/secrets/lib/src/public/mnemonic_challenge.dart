import 'package:flutter/widgets.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:secrets/src/public/secret.dart';

/// One tile in a [MnemonicChallenge]: a word to tap, and where it stands.
///
/// A value the host styles. It carries one word, never the list — and the
/// order the user is building is not in it either, so a host cannot
/// reassemble the mnemonic from the tiles it was handed.
final class MnemonicTile {
  final String word;

  /// Whether the user has already placed this tile.
  final bool isPlaced;

  /// The 1-based position the user gave it, or `null` while unplaced.
  final int? position;

  /// `null` once placed: a tile is tapped at most once.
  final VoidCallback? onTap;

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
/// The seal covers API leakage only. Screenshot blocking stays the host
/// screen's job; the semantics tree is excluded here.
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

  final Widget placeholder;
  final Widget Function(BuildContext, SecretFailure) onFailure;

  const MnemonicChallenge({
    super.key,
    required this.secret,
    required this.tileBuilder,
    required this.layout,
    required this.onSolved,
    required this.onMistake,
    required this.onFailure,
    this.onProgress,
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

  Future<Result<RevealedMnemonic, SecretFailure>> _reveal() async {
    final result = await widget.secret.revealWords(
      reason: RevealReason.physicalBackupCheck,
    );
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
    final placed = [for (final i in _placed) _shuffled[i], _shuffled[index]];

    // The running check: a wrong word is caught on the tap, not at the end.
    final correctSoFar = !placed.indexed.any((e) => _answer[e.$1] != e.$2);
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
    // check the audit surface names.
    switch (await widget.secret.verifyWords(placed)) {
      case Ok(value: true):
        widget.onSolved();
      case Ok(value: false):
        if (!mounted) return;
        setState(_reshuffle);
        widget.onProgress?.call(0, _answer.length);
        widget.onMistake();
      case Err():
        if (!mounted) return;
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
                    word: _shuffled[i],
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
