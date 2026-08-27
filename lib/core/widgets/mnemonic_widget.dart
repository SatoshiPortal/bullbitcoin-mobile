import 'dart:math';

import 'package:bb_mobile/core/failures/mnemonic_entry_failure.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/bip39.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/labeled_text_input.dart';
import 'package:bb_mobile/core/widgets/mnemonic_keyboard.dart';
import 'package:bb_mobile/core/widgets/mnemonic_entry_failure_l10n.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef Mnemonic = ({
  String label,
  String passphrase,
  List<String> words,
  bip39.Language language,
});

/// What the suggestion chips are currently answering: the focused field and
/// the prefix it holds.
/// [revision] only exists to force a notification: records compare
/// structurally, so an unchanged index and prefix would be swallowed even when
/// the candidate pool behind them has changed.
typedef _HintQuery = ({int index, String prefix, int revision});

class MnemonicWidget extends StatefulWidget {
  /// Only English is supported: the in-app keyboard is fixed to the 26 Latin
  /// letters, so a language with accented or non-Latin words (French, Spanish,
  /// Japanese, …) would leave most of its wordlist untypeable and the wallet
  /// impossible to import. Guarded by an assert rather than silently accepted.
  final bip39.Language language;
  final bip39.MnemonicLength initialLength;
  final Function(Mnemonic) onSubmit;
  final String submitLabel;
  final bool allowPassphrase;
  final bool allowLabel;
  final bool allowMultipleMnemonicLength;
  final bool allowAutoFillWords;

  final String? externalError;

  const MnemonicWidget({
    super.key,
    this.language = bip39.Language.english,
    required this.initialLength,
    required this.onSubmit,
    this.submitLabel = 'Submit',
    this.allowPassphrase = true,
    this.allowLabel = true,
    this.allowMultipleMnemonicLength = true,
    this.allowAutoFillWords = true,
    this.externalError,
  }) : assert(
         language == bip39.Language.english,
         'The in-app keyboard is Latin a–z only; non-English wordlists cannot '
         'be typed and would produce an un-importable wallet.',
       );

  @override
  State<MnemonicWidget> createState() => _MnemonicWidgetState();
}

/// Owns one [TextEditingController] per word.
///
/// The controllers are the single source of truth for what has been typed, so
/// a keystroke never has to travel up to this state and back down: the field
/// updates itself, and only the widgets actually listening to that controller
/// rebuild. This state rebuilds on the rare events only — length change and
/// submit error.
class _MnemonicWidgetState extends State<MnemonicWidget> {
  MnemonicEntryFailure? _failure;
  late bip39.MnemonicLength length;
  late List<TextEditingController> _controllers;
  String passphrase = '';
  String label = '';

  List<String> get _words =>
      _controllers.map((controller) => controller.text.trim()).toList();

  @override
  void initState() {
    super.initState();
    length = widget.initialLength;
    _controllers = _newControllers(length.words);
  }

  List<TextEditingController> _newControllers(int count) =>
      List.generate(count, (_) => TextEditingController());

  void onSubmit() {
    setState(() => _failure = null);
    final words = _words;

    if (words.any((word) => word.isEmpty)) {
      setState(() => _failure = const MnemonicEntryIncompleteFailure());
      return;
    }

    try {
      final mnemonic = bip39.Mnemonic.fromWords(
        words: words,
        language: widget.language,
        passphrase: passphrase,
      );
      widget.onSubmit((
        words: mnemonic.words,
        passphrase: passphrase,
        label: label,
        language: widget.language,
      ));
    } catch (e) {
      // The boundary where a library exception becomes a failure. Only the
      // *kind* of exception crosses: every `bip39.MnemonicException` message
      // embeds the offending word, so `e.toString()` would put a piece of the
      // user's seed on screen and into anything that later logs the failure.
      if (e is bip39.MnemonicInvalidChecksumException) {
        // The checksum lives in the last word, so that is the one to retype.
        _controllers.last.clear();
      }
      setState(
        () => _failure = switch (e) {
          bip39.MnemonicInvalidChecksumException() =>
            const MnemonicEntryInvalidChecksumFailure(),
          bip39.MnemonicWordNotFoundException() =>
            const MnemonicEntryUnknownWordFailure(),
          _ => MnemonicEntryUnexpectedFailure('${e.runtimeType}'),
        },
      );
    }
  }

  // No setState: the inputs keep their own text, and nothing else displays it.
  void updatePassphrase(String value) => passphrase = value;

  void updateLabel(String value) => label = value;

  void changeMnemonicLength(bip39.MnemonicLength value) {
    final previous = _controllers;
    setState(() {
      length = value;
      _controllers = _newControllers(length.words);
      _failure = null;
    });
    // Dispose only once the tree no longer references them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in previous) {
        controller.dispose();
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _keyboardBarSlot.dispose();
    super.dispose();
  }

  /// The docked keyboard bar is rendered here, below the scroll area, but its
  /// state lives in the sentence widget. The sentence registers a builder into
  /// this slot once mounted; this widget renders it. Docking (rather than
  /// floating in an overlay) means the scrollable fields occupy exactly the
  /// space above the keyboard, so a focused field is always reachable — the
  /// scroll simply flexes, which is what keeps small screens (iPhone mini,
  /// landscape) working without overflow.
  final ValueNotifier<WidgetBuilder?> _keyboardBarSlot = ValueNotifier(null);

  @override
  Widget build(BuildContext context) {
    final errorMessage =
        _failure?.toTranslated(context) ?? widget.externalError;

    return Column(
      children: [
        Expanded(
          // Tapping empty page space dismisses the keyboard. A word field taps
          // wins the gesture arena and keeps its focus, so only taps that land
          // on nothing reach this handler and unfocus.
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 16, right: 16),
              child: Column(
                children: [
                  if (widget.allowMultipleMnemonicLength) ...[
                    MnemonicLengthDropdown(
                      value: length,
                      onChanged: changeMnemonicLength,
                    ),
                    const Gap(16),
                  ],

                  MnemonicSentenceWidget(
                    controllers: _controllers,
                    language: widget.language,
                    allowAutoFillWords: widget.allowAutoFillWords,
                    keyboardBarSlot: _keyboardBarSlot,
                  ),

                  if (widget.allowPassphrase) ...[
                    const Gap(16),
                    LabeledTextInput(
                      label: 'Passphrase',
                      hint: 'Optional Passphrase',
                      value: passphrase,
                      onChanged: updatePassphrase,
                      maxLines: 1,
                      // A passphrase is key material too: keep it out of the
                      // IME's suggestion and autocorrect caches.
                      enableSuggestions: false,
                      autocorrect: false,
                      // iOS Smart Punctuation turns `'` into `’`, which
                      // would derive a different wallet. Disable it here
                      // rather than cleaning up the submitted value: `’`
                      // can be a real passphrase character.
                      smartQuotesType: SmartQuotesType.disabled,
                      smartDashesType: SmartDashesType.disabled,
                    ),
                  ],

                  if (widget.allowLabel) ...[
                    const Gap(16),
                    LabeledTextInput(
                      label: 'Label',
                      hint: 'Required',
                      value: label,
                      onChanged: updateLabel,
                      maxLines: 1,
                    ),
                  ],

                  if (errorMessage != null) ...[
                    const Gap(16),
                    BBText(
                      errorMessage,
                      style: context.font.bodyMedium,
                      color: context.appColors.error,
                    ),
                  ],

                  const Gap(16),
                  BBButton.big(
                    label: widget.submitLabel,
                    onPressed: onSubmit,
                    bgColor: context.appColors.onSurface,
                    textColor: context.appColors.surface,
                  ),
                  const Gap(16),
                ],
              ),
            ),
          ),
        ),
        // The docked keyboard, drawn below the scroll area. Empty until a word
        // field is focused.
        ValueListenableBuilder<WidgetBuilder?>(
          valueListenable: _keyboardBarSlot,
          builder: (context, barBuilder, _) =>
              barBuilder?.call(context) ?? const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// A single word field.
///
/// Stateless on purpose: the [TextField] is never rebuilt by a keystroke.
/// Only the index badge and the clear button depend on the typed text, and
/// each subscribes on its own.
///
/// The field is **read-only**: it never opens the platform keyboard and
/// refuses paste and the selection toolbar. Its controller is written only by
/// the in-app [MnemonicKeyboard], so the recovery phrase never travels through
/// a third-party IME. The field is purely a display of that controller.
class MnemonicWord extends StatelessWidget {
  final bip39.Language language;
  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;

  /// Non-null on the last field only: the checksum candidates, derived from
  /// every other word. The badge then answers "is this word acceptable", not
  /// "is this a word" - a wordlist word that cannot close the sentence is the
  /// wrong word, and the badge says so.
  final ValueListenable<List<String>?>? candidates;

  const MnemonicWord({
    super.key,
    this.language = bip39.Language.english,
    required this.index,
    required this.controller,
    required this.focusNode,
    this.candidates,
  });

  String get displayIndex {
    final displayIndex = index + 1;
    return displayIndex < 10 ? '0$displayIndex' : '$displayIndex';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.appColors.border),
        color: context.appColors.surface,
      ),
      height: 41,
      child: Row(
        children: [
          ListenableBuilder(
            listenable: candidates == null
                ? controller
                : Listenable.merge([controller, candidates!]),
            builder: (context, _) {
              final word = controller.text.trim();
              // With a candidate pool (last field), acceptability means
              // closing the checksum; without one, plain wordlist membership.
              final pool = candidates?.value;
              final isValid = pool != null
                  ? pool.contains(word)
                  : language.isValid(word);
              return Container(
                height: 34,
                width: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: word.isEmpty
                      ? context.appColors.onSurface
                      : isValid
                      ? context.appColors.success
                      : context.appColors.error,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: BBText(
                  displayIndex,
                  style: context.font.headlineMedium,
                  color: context.appColors.surface,
                  textAlign: .right,
                ),
              );
            },
          ),
          const Gap(4),
          Expanded(
            // Read-only: the platform keyboard never opens, paste and the
            // selection toolbar are suppressed. The only writer of this
            // controller is the in-app MnemonicKeyboard, so no keystroke of
            // the seed leaves the app process.
            child: TextField(
              readOnly: true,
              showCursor: true,
              enableInteractiveSelection: false,
              contextMenuBuilder: (_, _) => const SizedBox.shrink(),
              enableSuggestions: false,
              autocorrect: false,
              controller: controller,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.text,
              ),
              focusNode: focusNode,
              clipBehavior: .antiAliasWithSaveLayer,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.only(right: 8),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: context.appColors.transparent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: context.appColors.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: context.appColors.transparent),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                onPressed: controller.clear,
                icon: Icon(
                  Icons.close,
                  size: 24,
                  color: context.appColors.text,
                ),
                padding: EdgeInsets.zero,
              );
            },
          ),
        ],
      ),
    );
  }
}

class MnemonicSentenceWidget extends StatefulWidget {
  static const int columns = 2;
  final List<TextEditingController> controllers;
  final bip39.Language language;
  final bool allowAutoFillWords;

  /// A slot, owned by the parent, into which this widget publishes its docked
  /// keyboard bar builder. The parent renders it below the scroll area so the
  /// keyboard is docked rather than floating, and the fields scroll in exactly
  /// the space that remains above it.
  final ValueNotifier<WidgetBuilder?>? keyboardBarSlot;

  const MnemonicSentenceWidget({
    super.key,
    required this.controllers,
    required this.language,
    this.allowAutoFillWords = true,
    this.keyboardBarSlot,
  });

  @override
  State<MnemonicSentenceWidget> createState() => _MnemonicSentenceWidgetState();
}

class _MnemonicSentenceWidgetState extends State<MnemonicSentenceWidget> {
  final ValueNotifier<_HintQuery> _hint = ValueNotifier((
    index: 0,
    prefix: '',
    revision: 0,
  ));
  int _revision = 0;
  final List<VoidCallback> _textListeners = [];
  List<FocusNode> _focusNodes = [];

  /// The word field the in-app keyboard currently types into, or null when no
  /// word field is focused. Drives both the keyboard's visibility and which
  /// controller a key tap writes to.
  final ValueNotifier<int?> _activeField = ValueNotifier(null);

  /// Paranoid mode: the keyboard shows a randomised letter layout instead of
  /// QWERTY. Toggled by the shuffle button.
  final ValueNotifier<bool> _paranoid = ValueNotifier(false);

  /// The current randomised order, regenerated on every key tap while paranoid
  /// so a key never sits in the same place twice — nothing can be learned from
  /// watching finger positions or a screen recording.
  List<String> _shuffledLayout = MnemonicKeyboard.qwerty;
  final Random _random = Random.secure();

  /// Caches the shuffled suggestion order for one _hint query, so the chips
  /// reshuffle once per keystroke rather than on every rebuild.
  _HintQuery? _shuffledHintsFor;
  List<String>? _shuffledHintsOrder;

  /// The last field's checksum candidates, mirrored as a listenable so the
  /// last badge can judge acceptability against the pool - and refresh when
  /// another word changes the pool.
  final ValueNotifier<List<String>?> _candidatePool = ValueNotifier(null);
  String? _candidatesKey;
  List<String>? _candidates;

  @override
  void initState() {
    super.initState();
    _attach();
    // Publish the docked keyboard builder to the parent once mounted. Deferred
    // to a post-frame callback so the parent is not marked dirty during its own
    // build; the keyboard is hidden until a field is focused, so the one-frame
    // delay is invisible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.keyboardBarSlot?.value = _buildKeyboardBar;
    });
  }

  @override
  void didUpdateWidget(MnemonicSentenceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controllers, widget.controllers)) {
      final retiredNodes = _focusNodes;
      _detach(oldWidget.controllers);
      _attach();
      _candidatesKey = null;
      // Every notifier mutation is deferred to a post-frame callback: firing
      // them here, mid-build, would mark the listening keyboard bar and the
      // last field's badge dirty during the build phase, which is illegal —
      // the bar is rendered by the parent, not by this subtree. A length
      // change rebuilds every field: no field is focused any more, so the
      // keyboard has nothing to type into.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _activeField.value = null;
        _candidatePool.value = null;
        _hint.value = (index: 0, prefix: '', revision: ++_revision);
        // The old fields still referenced these until they rebuilt earlier in
        // this frame: dispose only once the tree no longer holds them, the
        // same courtesy the parent extends to the old controllers.
        for (final node in retiredNodes) {
          node.dispose();
        }
      });
    }
  }

  @override
  void dispose() {
    _detach(widget.controllers);
    for (final node in _focusNodes) {
      node.dispose();
    }
    _hint.dispose();
    _activeField.dispose();
    _paranoid.dispose();
    _candidatePool.dispose();
    super.dispose();
  }

  void _attach() {
    _focusNodes = List.generate(widget.controllers.length, (_) {
      final node = FocusNode();
      node.addListener(_onFocusChanged);
      return node;
    });
    for (var index = 0; index < widget.controllers.length; index++) {
      final position = index;
      void listener() => _onTextChanged(position);
      _textListeners.add(listener);
      widget.controllers[index].addListener(listener);
    }
  }

  void _detach(List<TextEditingController> controllers) {
    for (var i = 0; i < controllers.length && i < _textListeners.length; i++) {
      controllers[i].removeListener(_textListeners[i]);
    }
    _textListeners.clear();
  }

  /// Focus is the single source of truth for the active field: whichever node
  /// currently holds it decides where a key tap goes and keeps the keyboard
  /// up; when none does, the keyboard leaves. Reading the live focus state
  /// (rather than the node that fired) is robust to the brief moment during a
  /// field-to-field move when the losing node reports first.
  void _onFocusChanged() {
    final index = _focusNodes.indexWhere((node) => node.hasFocus);
    if (index >= 0) {
      _activeField.value = index;
      _refreshHint(index);
      _ensureFieldVisible(index);
    } else {
      _activeField.value = null;
    }
  }

  /// Scrolls the focused field into the area left above the docked keyboard.
  ///
  /// Deferred to after the frame: focusing a field grows the keyboard bar,
  /// which shrinks the scroll viewport, so the target position is only known
  /// once that layout has settled. Centering keeps the field clear of both the
  /// keyboard below and the top edge on small screens.
  void _ensureFieldVisible(int index) {
    // Capture the node, not the index: a length change can replace
    // [_focusNodes] with a shorter list before the callback runs, and
    // dereferencing the stale index there would throw a RangeError.
    final node = _focusNodes[index];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The captured node was retired by a length change: nothing to scroll to.
      if (!_focusNodes.contains(node)) return;
      final context = node.context;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _onTextChanged(int index) {
    // The pool is derived from every word but the last; the cached answer is
    // a new instance only when it actually changed.
    final pool = _lastWordCandidates();
    if (!identical(pool, _candidatePool.value)) {
      _candidatePool.value = pool;
    }
    final hinted = _hint.value.index;
    if (hinted == index) {
      _refreshHint(index);
    } else if (hinted == widget.controllers.length - 1) {
      // The candidate pool of the last field is derived from every other word,
      // so a change anywhere invalidates it - typically the clear button, which
      // edits a field without moving focus.
      _refreshHint(hinted, force: true);
    }
    _maybeAutoFill(index);
  }

  /// Cached: the answer only changes when a word other than the last does,
  /// so typing in the last field does not recompute it.
  List<String>? _lastWordCandidates() {
    final previous = [
      for (var i = 0; i < widget.controllers.length - 1; i++)
        widget.controllers[i].text.trim(),
    ];
    final key = previous.join(' ');
    if (key != _candidatesKey) {
      _candidatesKey = key;
      _candidates = Bip39WordList.lastWordCandidates(
        words: previous,
        language: widget.language,
      );
    }
    return _candidates;
  }

  /// [force] bumps [_revision] so the notifier fires even though index and
  /// prefix are unchanged: `_HintQuery` is a record, so equal values are not
  /// notified. Left alone otherwise, to keep an unchanged prefix free.
  void _refreshHint(int index, {bool force = false}) {
    if (force) _revision++;
    _hint.value = (
      index: index,
      prefix: widget.controllers[index].text.trim(),
      revision: _revision,
    );
  }

  /// Completes the field as soon as the prefix leaves a single possibility.
  ///
  /// Deliberately resolved against the **whole** wordlist, including on the
  /// last field where the chips are narrowed to the checksum candidates.
  /// Completing from the candidates instead would absorb a transcription
  /// error: if an earlier word was mistyped into another valid word, the real
  /// last word is not a candidate, yet a two letter prefix of it can single
  /// out a different candidate. The sentence would then pass the checksum and
  /// be accepted - turning the one error the checksum exists to catch into a
  /// silently restored wrong wallet.
  ///
  /// Runs on the text-change notification rather than during build, where the
  /// previous implementation scheduled it as a post-frame side effect.
  ///
  /// Once the field holds the only word left, the in-app keyboard has no
  /// letter to offer anyway (no wordlist word extends a uniquely-determined
  /// one), so the word cannot be broken by a further tap - the old edit "lock"
  /// is redundant under keyboard-only input. Focus stays put, except on the
  /// last word, where a completed sentence is the natural moment to dismiss
  /// the keyboard.
  void _maybeAutoFill(int index) {
    if (!widget.allowAutoFillWords) return;
    final prefix = widget.controllers[index].text.trim();
    if (prefix.isEmpty) return;

    // Stop at the second match: only ambiguity matters here, not the count.
    final matches = widget.language.list
        .where((word) => word.startsWith(prefix))
        .take(2)
        .toList();
    if (matches.length == 1 && matches.first != prefix) {
      _setWord(index, matches.first);
      if (index == widget.controllers.length - 1) {
        _focusNodes[index].unfocus();
      }
    }
  }

  /// Writes [word] to field [index], caret at the end so the visible text
  /// tracks what was typed. The controller listener does the rest (candidate
  /// refresh, hint, auto fill).
  void _setWord(int index, String word) {
    widget.controllers[index].value = TextEditingValue(
      text: word,
      selection: TextSelection.collapsed(offset: word.length),
    );
  }

  /// Appends a letter to the active field. Routed here from the in-app
  /// keyboard, the only writer of the word fields' text.
  ///
  /// The model, not the key widget, is authoritative: a key's `enabled` flag is
  /// captured at build time, so a second tap fired in the same frame as the
  /// first still runs the stale (enabled) handler. Re-checking the letter
  /// against the live prefix here drops that racing tap, so a burst of taps can
  /// never append a letter that cannot begin a wordlist word (e.g. `aa`).
  void _onKeyLetter(String letter) {
    final index = _activeField.value;
    if (index == null) return;
    final prefix = widget.controllers[index].text;
    final allowed = Bip39WordList.allowedNextLetters(
      prefix: prefix,
      language: widget.language,
    );
    if (!allowed.contains(letter)) return;
    _reshuffleIfParanoid();
    _setWord(index, prefix + letter);
  }

  /// Clears the whole active field. A word is entered as one unit against the
  /// wordlist, so it is deleted as one unit too: backspace wipes the field
  /// rather than trimming a letter. The emptied field re-enables every letter
  /// on the next build.
  void _onKeyBackspace() {
    final index = _activeField.value;
    if (index == null) return;
    if (widget.controllers[index].text.isEmpty) return;
    _reshuffleIfParanoid();
    _setWord(index, '');
  }

  /// Toggles paranoid mode. Enabling it shuffles the layout immediately so the
  /// very first key is already in a random place.
  void _toggleParanoid() {
    final enabling = !_paranoid.value;
    if (enabling) _shuffle();
    _paranoid.value = enabling;
  }

  /// Reshuffles before each key tap while paranoid, so the next repaint of the
  /// keyboard (driven by the resulting text change) lands on a fresh layout.
  void _reshuffleIfParanoid() {
    if (_paranoid.value) _shuffle();
  }

  void _shuffle() {
    // Reject an arrangement too close to the current one: a shuffle that leaves
    // most letters in place looks like nothing changed and invites a mistap
    // from muscle memory. Require at least 20 of 26 positions to move.
    final previous = _shuffledLayout;
    List<String> next;
    do {
      next = List.of(MnemonicKeyboard.qwerty)..shuffle(_random);
    } while (_samePositions(next, previous) > 6);
    _shuffledLayout = next;
  }

  int _samePositions(List<String> a, List<String> b) {
    var same = 0;
    for (var i = 0; i < a.length; i++) {
      if (a[i] == b[i]) same++;
    }
    return same;
  }

  /// The docked bottom bar: the suggestion chips sit directly above the keys,
  /// like a system keyboard's suggestion strip, so neither the chips nor a
  /// focused field is ever hidden behind the keyboard. Empty until a word
  /// field is focused. Rendered by the parent below the scroll area (via
  /// [MnemonicSentenceWidget.keyboardBarSlot]).
  ///
  /// [ExcludeFocus] keeps every tap target here out of focus traversal: the
  /// keys and chips must never steal focus from the word field being typed
  /// into.
  Widget _buildKeyboardBar(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_activeField, _paranoid]),
      builder: (context, _) {
        if (_activeField.value == null) return const SizedBox.shrink();
        final paranoid = _paranoid.value;
        return ExcludeFocus(
          child: Material(
            color: context.appColors.surfaceContainer,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    // Suggestions stay visible in paranoid mode; they are only
                    // shuffled (see _buildHintsList), so an onlooker cannot map
                    // a chip position to a word either. ExcludeSemantics: the
                    // chips are plain-text word candidates — an accessibility
                    // service must not read them any more than the keys.
                    child: ExcludeSemantics(
                      child: _buildHintsList(paranoid: paranoid),
                    ),
                  ),
                  _buildKeyboard(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeyboard() {
    // Driven by _hint, which already carries the focused field's live prefix
    // and is refreshed on every focus change and keystroke. Using it (rather
    // than the controllers) keeps the keyboard independent of the controller
    // list, so it survives a length change without re-subscribing. Reading the
    // layout inside the builder means each keystroke picks up the freshly
    // reshuffled order while paranoid.
    return ValueListenableBuilder<_HintQuery>(
      valueListenable: _hint,
      builder: (context, query, _) {
        final prefix = query.prefix;
        return MnemonicKeyboard(
          layout: _paranoid.value ? _shuffledLayout : MnemonicKeyboard.qwerty,
          enabledLetters: Bip39WordList.allowedNextLetters(
            prefix: prefix,
            language: widget.language,
          ),
          canBackspace: prefix.isNotEmpty,
          canAdvance: _canLeaveField(prefix),
          onLetter: _onKeyLetter,
          onBackspace: _onKeyBackspace,
          onEnter: _onKeyEnter,
          shuffleActive: _paranoid.value,
          onToggleShuffle: _toggleParanoid,
          shuffleHint: context.loc.mnemonicShuffleKeyboardHint,
        );
      },
    );
  }

  void _focusNext(int nextIndex) {
    if (nextIndex >= 0 && nextIndex < _focusNodes.length) {
      FocusScope.of(context).requestFocus(_focusNodes[nextIndex]);
    }
  }

  /// Whether [word] is a wordlist entry rather than a prefix of one.
  ///
  /// Against the whole wordlist even on the last field: narrowing to the
  /// checksum candidates would swallow a transcription error, as
  /// [_maybeAutoFill] explains.
  bool _isWholeWord(String word) => widget.language.list.contains(word);

  /// A field can be left once it is finished, or if it was never started. A
  /// half-typed prefix is neither: leaving it parks a fragment that reads like
  /// a word.
  bool _canLeaveField(String word) => word.isEmpty || _isWholeWord(word);

  /// The keyboard's counterpart to tapping the next field. Never writes to the
  /// sentence.
  ///
  /// Re-checks the live text like [_onKeyLetter] does: `enabled` is captured at
  /// build time, so a tap racing that frame would still land here.
  void _onKeyEnter() {
    final index = _activeField.value;
    if (index == null) return;
    if (!_canLeaveField(widget.controllers[index].text.trim())) return;
    // Last word: dismiss rather than wrap, like the auto fill and a chip tap.
    if (index == widget.controllers.length - 1) {
      _focusNodes[index].unfocus();
    } else {
      _focusNext(index + 1);
    }
  }

  void _onHintTap(int index, String word) {
    _setWord(index, word);
    // Like the auto fill, a tapped chip completes the sentence on the last
    // field: the same natural moment to dismiss the keyboard.
    if (index == widget.controllers.length - 1) {
      _focusNodes[index].unfocus();
    } else {
      _focusNext(index + 1);
    }
  }

  Widget _buildHintsList({required bool paranoid}) {
    const height = 50.0;
    return ValueListenableBuilder<_HintQuery>(
      valueListenable: _hint,
      builder: (context, query, _) {
        final isLastWord = query.index == widget.controllers.length - 1;
        // Null means the question does not apply - an earlier word is missing
        // or unknown - which is exactly the signal for falling back.
        final candidates = isLastWord ? _lastWordCandidates() : null;
        final pool = candidates ?? widget.language.list;
        final predicting = candidates != null;

        // Materialized: elementAt on a lazy where() walks the wordlist again
        // for every chip the list scrolls to.
        final hints = pool
            .where((word) => word.startsWith(query.prefix))
            .toList();

        // Paranoid mode randomises the chip order so a chip's position leaks
        // nothing about which word it is. Cached per _hint query (which bumps
        // once per keystroke) so the order is stable across unrelated rebuilds
        // — otherwise the chips would jitter on every repaint.
        if (paranoid) {
          if (query != _shuffledHintsFor) {
            hints.shuffle(_random);
            _shuffledHintsFor = query;
            _shuffledHintsOrder = hints;
          } else {
            hints
              ..clear()
              ..addAll(_shuffledHintsOrder!);
          }
        }

        // The field already holds the single matching word: the question is
        // answered, so both the chips and the count label leave.
        final completed = hints.length == 1 && hints.first == query.prefix;

        return Column(
          crossAxisAlignment: .start,
          children: [
            if (predicting && !completed) ...[
              BBText(
                context.loc.mnemonicPossibleLastWords(pool.length),
                style: context.font.labelSmall,
                color: context.appColors.textMuted,
              ),
              const Gap(4),
            ],
            SizedBox(
              height: height,
              child: completed
                  ? null
                  : ListView.separated(
                      key: ValueKey(query.index),
                      scrollDirection: .horizontal,
                      itemCount: hints.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => _HintChip(
                        word: hints[index],
                        onTap: () => _onHintTap(query.index, hints[index]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.controllers.length;
    final splitIndex = (count / MnemonicSentenceWidget.columns).floor();

    Widget column(int from, int to) => Column(
      spacing: 16,
      crossAxisAlignment: .start,
      children: [
        for (var index = from; index < to; index++)
          MnemonicWord(
            index: index,
            controller: widget.controllers[index],
            language: widget.language,
            focusNode: _focusNodes[index],
            candidates: index == count - 1 ? _candidatePool : null,
          ),
      ],
    );

    // ExcludeSemantics: a TextField publishes its text as its semantics
    // value, so without this the fields would narrate the seed letter by
    // letter to any accessibility service — the very attacker the read-only
    // fields and the excluded keyboard keys are meant to defeat. The badges
    // and clear icons go with them: this screen is unusable with a screen
    // reader by design, the recovery phrase is too sensitive to narrate.
    return ExcludeSemantics(
      child: Row(
        crossAxisAlignment: .start,
        spacing: 16,
        children: [
          Expanded(child: column(0, splitIndex)),
          Expanded(child: column(splitIndex, count)),
        ],
      ),
    );
  }
}

class MnemonicLengthDropdown extends StatelessWidget {
  final bip39.MnemonicLength value;
  final Function(bip39.MnemonicLength) onChanged;

  const MnemonicLengthDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<bip39.MnemonicLength>(
      value: value,
      underline: const SizedBox(),
      style: context.font.bodyMedium?.copyWith(
        fontWeight: .w600,
        color: context.appColors.text,
      ),
      dropdownColor: context.appColors.surface,
      borderRadius: BorderRadius.circular(4),
      items: bip39.MnemonicLength.values
          .map(
            (length) => DropdownMenuItem(
              value: length,
              child: BBText(
                '${length.words} words',
                style: context.font.bodyMedium?.copyWith(
                  fontWeight: .w600,
                  color: context.appColors.text,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (v) => onChanged(v ?? bip39.MnemonicLength.words12),
    );
  }
}

class _HintChip extends StatelessWidget {
  final String word;
  final VoidCallback onTap;

  const _HintChip({required this.word, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      // A suggestion must never take focus from the word field being typed into.
      canRequestFocus: false,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: context.appColors.surface,
          border: Border.all(color: context.appColors.border),
        ),
        child: Center(child: BBText(word, style: context.font.bodyLarge)),
      ),
    );
  }
}
