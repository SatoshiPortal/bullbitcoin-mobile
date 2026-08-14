import 'package:bb_mobile/core/failures/mnemonic_entry_failure.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/bip39.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/labeled_text_input.dart';
import 'package:bb_mobile/core/widgets/mnemonic_entry_failure_l10n.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  });

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

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
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
  Widget build(BuildContext context) {
    final errorMessage =
        _failure?.toTranslated(context) ?? widget.externalError;

    return Padding(
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
          ),

          if (widget.allowPassphrase) ...[
            const Gap(16),
            LabeledTextInput(
              label: 'Passphrase',
              hint: 'Optional Passphrase',
              value: passphrase,
              onChanged: updatePassphrase,
              maxLines: 1,
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
        ],
      ),
    );
  }
}

/// A single word field.
///
/// Stateless on purpose: the [TextField] is never rebuilt by a keystroke.
/// Only the index badge and the clear button depend on the typed text, and
/// each subscribes on its own; the field itself rebuilds once per auto fill,
/// when [fieldLock] starts swallowing its edits.
class MnemonicWord extends StatelessWidget {
  final bip39.Language language;
  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onComplete;

  /// Set by the auto fill once it completes the word: the field keeps focus
  /// and the keyboard, but swallows any further edit until it is emptied, so
  /// a stray keystroke cannot break a word that was the only possibility left.
  final ValueListenable<bool> fieldLock;

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
    required this.onComplete,
    required this.fieldLock,
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
            child: ValueListenableBuilder<bool>(
              valueListenable: fieldLock,
              builder: (context, locked, _) {
                return TextField(
                  enableSuggestions: false,
                  autocorrect: false,
                  controller: controller,
                  inputFormatters: [
                    // A locked word was the only possibility left: swallow any
                    // further typing instead of closing the keyboard - the
                    // field stays focused and editable, but the word cannot be
                    // broken. A deletion empties the field instead, which
                    // unlocks it: backspace is the user's undo instinct, and
                    // the clear icon remains the explicit way out.
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      if (!locked) return newValue;
                      final isDeletion =
                          newValue.text.length < oldValue.text.length;
                      return isDeletion ? TextEditingValue.empty : oldValue;
                    }),
                    // Keeps the previous behaviour of lowercasing as you type.
                    // Same length in and out, so the caret position stays valid.
                    TextInputFormatter.withFunction(
                      (_, value) =>
                          value.copyWith(text: value.text.toLowerCase()),
                    ),
                  ],
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.text,
                  ),
                  focusNode: focusNode,
                  clipBehavior: .antiAliasWithSaveLayer,
                  onEditingComplete: onComplete,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.only(right: 8),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: context.appColors.transparent,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: context.appColors.transparent,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: context.appColors.transparent,
                      ),
                    ),
                  ),
                );
              },
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

  const MnemonicSentenceWidget({
    super.key,
    required this.controllers,
    required this.language,
    this.allowAutoFillWords = true,
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

  /// One lock per field, set by the auto fill: a completed word was the only
  /// possibility left, so further typing could only break it. Emptied fields
  /// are editable again, whatever emptied them.
  List<ValueNotifier<bool>> _fieldLocks = [];

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
  }

  @override
  void didUpdateWidget(MnemonicSentenceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controllers, widget.controllers)) {
      final retiredNodes = _focusNodes;
      final retiredLocks = _fieldLocks;
      _detach(oldWidget.controllers);
      _attach();
      _candidatesKey = null;
      _candidatePool.value = null;
      _hint.value = (index: 0, prefix: '', revision: ++_revision);
      // The old fields still reference these until they rebuild later in
      // this frame: dispose only once the tree no longer holds them, the
      // same courtesy the parent extends to the old controllers.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final node in retiredNodes) {
          node.dispose();
        }
        for (final lock in retiredLocks) {
          lock.dispose();
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
    for (final lock in _fieldLocks) {
      lock.dispose();
    }
    _hint.dispose();
    _candidatePool.dispose();
    super.dispose();
  }

  void _attach() {
    _focusNodes = List.generate(widget.controllers.length, (index) {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) _refreshHint(index);
      });
      return node;
    });
    _fieldLocks = List.generate(
      widget.controllers.length,
      (_) => ValueNotifier(false),
    );
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

  void _onTextChanged(int index) {
    // A locked field can only be emptied - by the clear icon, or by the
    // parent clearing the last word on a checksum failure - and an emptied
    // field is editable again.
    if (widget.controllers[index].text.isEmpty) {
      _fieldLocks[index].value = false;
    }
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
  /// The completed field locks: the match was the only one left, so another
  /// keystroke could only break a certain word. Focus stays put and the
  /// keyboard stays up - except on the last word, where a completed sentence
  /// is the natural moment to dismiss it. The clear icon unlocks the field.
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
      widget.controllers[index].text = matches.first;
      _fieldLocks[index].value = true;
      if (index == widget.controllers.length - 1) {
        _focusNodes[index].unfocus();
      }
    }
  }

  void _focusNext(int nextIndex) {
    if (nextIndex >= 0 && nextIndex < _focusNodes.length) {
      FocusScope.of(context).requestFocus(_focusNodes[nextIndex]);
    }
  }

  void _onHintTap(int index, String word) {
    widget.controllers[index].text = word;
    // Like the auto fill, a tapped chip completes the sentence on the last
    // field: the same natural moment to dismiss the keyboard.
    if (index == widget.controllers.length - 1) {
      _focusNodes[index].unfocus();
    } else {
      _focusNext(index + 1);
    }
  }

  Widget _buildHintsList() {
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
            onComplete: () => _focusNext(index + 1),
            fieldLock: _fieldLocks[index],
            candidates: index == count - 1 ? _candidatePool : null,
          ),
      ],
    );

    return Column(
      children: [
        Row(
          crossAxisAlignment: .start,
          spacing: 16,
          children: [
            Expanded(child: column(0, splitIndex)),
            Expanded(child: column(splitIndex, count)),
          ],
        ),
        const Gap(16),
        _buildHintsList(),
      ],
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
