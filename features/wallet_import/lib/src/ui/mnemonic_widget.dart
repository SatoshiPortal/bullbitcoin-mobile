import 'dart:math';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullButtonSize,
        BullKeyScramble,
        BullKeyboardLanguage,
        BullLabeledTextInput,
        BullMnemonicKeyboard,
        BullSecretTextInput,
        BullSegmented,
        BullShapesX,
        BullSwitch,
        BullText,
        BullThemeX,
        BullTypographyX,
        Gap;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallet_import/src/domain/bip39_word_list.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/mnemonic.dart';
import 'package:wallet_import/src/presentation/import_l10n.dart';
import 'package:wallet_import/src/presentation/mnemonic_entry_failure_l10n.dart';
import 'package:wallet_import/src/ui/mnemonic_keyboard_layout.dart';

/// What the suggestion chips are currently answering: the focused field and
/// the prefix it holds.
/// [revision] invalidates callbacks when focus, language, controllers, or any
/// word changes, including when the focused prefix itself stays unchanged.
typedef _HintQuery = ({int index, String prefix, int revision});

/// The docked keyboard as the sentence publishes it: whether a word field is
/// being typed, and how to draw the keyboard while it is.
typedef MnemonicKeyboardBar = ({
  ValueListenable<int?> activeField,
  WidgetBuilder build,
});

// All BIP39 wordlists use the protected in-app keyboard.
const _entryLanguages = [
  bip39.Language.english,
  bip39.Language.spanish,
  bip39.Language.french,
  bip39.Language.italian,
  bip39.Language.czech,
  bip39.Language.portuguese,
  bip39.Language.japanese,
  bip39.Language.korean,
  bip39.Language.simplifiedChinese,
  bip39.Language.traditionalChinese,
];

/// The code the language key shows for each wordlist.
String _languageCode(bip39.Language language) => switch (language) {
  bip39.Language.english => 'EN',
  bip39.Language.spanish => 'ES',
  bip39.Language.french => 'FR',
  bip39.Language.italian => 'IT',
  bip39.Language.czech => 'CS',
  bip39.Language.portuguese => 'PT',
  bip39.Language.japanese => 'JA',
  bip39.Language.korean => 'KO',
  bip39.Language.simplifiedChinese || bip39.Language.traditionalChinese => 'ZH',
};

class MnemonicWidget extends StatefulWidget {
  /// Initial wordlist. Choosing another one on the keyboard's language key
  /// clears the entered words only when some are written in another wordlist;
  /// resolving a detected or ambiguous language from the notices always keeps
  /// them, since they are valid in the chosen wordlist.
  final bip39.Language language;
  final bip39.MnemonicLength initialLength;
  final Function(Mnemonic) onSubmit;
  final String? submitLabel;
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
    this.submitLabel,
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
class _MnemonicWidgetState extends State<MnemonicWidget>
    with WidgetsBindingObserver {
  MnemonicEntryFailure? _failure;
  late bip39.MnemonicLength length;
  late bip39.Language _language;

  /// An explicit choice answers one phrase only: any word edit or length
  /// change asks again (see [_onWordEdited]).
  bool _languageConfirmed = false;
  bool _needsLanguageChoice = false;
  final _languageNoticeKey = GlobalKey();
  final _errorKey = GlobalKey();
  late List<TextEditingController> _controllers;

  /// The texts last seen per field, so a caret-only notification does not
  /// count as an edit. References to the controllers' own strings, no copy.
  List<String> _seenTexts = [];
  String passphrase = '';
  bool _showPassphrase = false;
  bool _passphraseCleared = false;
  int _passphraseGeneration = 0;
  String label = '';

  /// Bumped when a reset should leave the first word focused, so the keyboard
  /// stays up on the new wordlist.
  int _focusFirstWordRequest = 0;

  List<String> get _words => _controllers
      .map((controller) => Bip39WordList.normalize(controller.text))
      .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    length = widget.initialLength;
    _language = widget.language;
    _controllers = _newControllers(length.words);
    _watchEdits(_controllers);
  }

  List<TextEditingController> _newControllers(int count) =>
      List.generate(count, (_) => TextEditingController());

  void _watchEdits(List<TextEditingController> controllers) {
    _seenTexts = [for (final controller in controllers) controller.text];
    for (final controller in controllers) {
      controller.addListener(_onWordEdited);
    }
  }

  /// No setState: only the language section reads these flags, and it already
  /// rebuilds on every controller notification.
  void _onWordEdited() {
    var edited = false;
    for (var i = 0; i < _controllers.length && i < _seenTexts.length; i++) {
      if (_controllers[i].text != _seenTexts[i]) {
        _seenTexts[i] = _controllers[i].text;
        edited = true;
      }
    }
    if (!edited) return;
    _languageConfirmed = false;
    _needsLanguageChoice = false;
  }

  void onSubmit() {
    if (_passphraseCleared && passphrase.isEmpty) return;
    setState(() {
      _failure = null;
      _needsLanguageChoice = false;
    });
    final words = _words;

    if (words.any((word) => word.isEmpty)) {
      log.warning('Mnemonic submit refused reason=incomplete');
      setState(() => _failure = const MnemonicEntryIncompleteFailure());
      _showError();
      return;
    }

    // Valid readings (membership and checksum) decide, never membership
    // alone: the English and French lists share 100 words.
    final readings = Bip39WordList.matchingLanguages(
      words,
      requireChecksum: true,
    );
    if (readings.isNotEmpty &&
        (!readings.contains(_language) ||
            (readings.length > 1 && !_languageConfirmed))) {
      log.warning('Mnemonic submit refused reason=language_required');
      setState(() => _needsLanguageChoice = readings.length > 1);
      _showLanguageNotice();
      return;
    }
    if (readings.isEmpty && !words.every(_language.isValid)) {
      // No valid reading, and the words are not the selected language's:
      // "unknown word" would be wrong when another wordlist knows them all.
      final others = Bip39WordList.matchingLanguages(words);
      if (others.isNotEmpty) {
        log.warning('Mnemonic submit refused reason=language_required');
        setState(
          () => _failure = MnemonicEntryOtherLanguageFailure(
            wordlist: others.first,
            selected: _language,
          ),
        );
        _showError();
        return;
      }
    }

    try {
      final mnemonic = bip39.Mnemonic.fromWords(
        words: words,
        language: _language,
        passphrase: passphrase,
      );
      widget.onSubmit((
        words: mnemonic.words,
        passphrase: passphrase,
        label: label,
        language: _language,
      ));
    } catch (e) {
      // The boundary where a library exception becomes a failure. Only the
      // *kind* of exception crosses: every `bip39.MnemonicException` message
      // embeds the offending word, so `e.toString()` would put a piece of the
      // user's seed on screen and into anything that later logs the failure.
      final reason = switch (e) {
        bip39.MnemonicInvalidChecksumException() => 'checksum',
        bip39.MnemonicWordNotFoundException() => 'unknown_word',
        _ => 'validation',
      };
      log.warning('Mnemonic submit refused reason=$reason');
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
      _showError();
    }
  }

  // No setState: the inputs keep their own text, and nothing else displays it.
  void updatePassphrase(String value) => setState(() => passphrase = value);

  /// Turning the passphrase off drops what was typed, so a field opened by
  /// mistake never leaves a hidden passphrase behind.
  void _setPassphraseEnabled(bool enabled) => setState(() {
    _showPassphrase = enabled;
    if (enabled) return;
    passphrase = '';
    _passphraseCleared = false;
    _passphraseGeneration++;
  });

  void updateLabel(String value) => label = value;

  void changeMnemonicLength(bip39.MnemonicLength value) =>
      _resetWords(() => length = value);

  /// A new word count or a new wordlist starts a new phrase: fresh empty
  /// fields, and every answer about the previous phrase dropped.
  void _resetWords(VoidCallback change, {bool focusFirstWord = false}) {
    final previous = _controllers;
    for (final controller in previous) {
      controller.removeListener(_onWordEdited);
    }
    setState(() {
      change();
      if (focusFirstWord) _focusFirstWordRequest++;
      _controllers = _newControllers(length.words);
      _watchEdits(_controllers);
      _languageConfirmed = false;
      _needsLanguageChoice = false;
      _failure = null;
    });
    // Dispose only once the tree no longer references them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in previous) {
        controller.dispose();
      }
    });
  }

  void _showLanguageNotice() {
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final noticeContext = _languageNoticeKey.currentContext;
      if (noticeContext == null) return;
      Scrollable.ensureVisible(noticeContext, alignment: 0);
    });
  }

  /// The error sits at the end of the scroll while the submit button is pinned
  /// under it, so a long phrase would leave it below the fold.
  void _showError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final errorContext = _errorKey.currentContext;
      if (errorContext == null) return;
      Scrollable.ensureVisible(errorContext, alignment: 1);
    });
  }

  @override
  void didUpdateWidget(covariant MnemonicWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalError != null &&
        widget.externalError != oldWidget.externalError) {
      _showError();
    }
  }

  /// The keyboard's language key. Words written in another wordlist belong
  /// to another phrase: if any entered word is neither a word of [language]
  /// nor, in the field being typed ([typing]), a prefix of one, the words are
  /// cleared and typing resumes on the first word. Otherwise they stay. The
  /// current wordlist changes nothing.
  void _chooseKeyboardLanguage(bip39.Language language, int? typing) {
    if (!_entryLanguages.contains(language) || language == _language) return;
    log.config('Mnemonic language selected language=${language.name}');
    final words = _words;
    final foreign = [
      for (final (index, word) in words.indexed)
        if (word.isNotEmpty &&
            !language.isValid(word) &&
            !(index == typing &&
                language.list.any(
                  (entry) => Bip39WordList.normalize(entry).startsWith(word),
                )))
          index,
    ];
    if (foreign.isNotEmpty) {
      _resetWords(() => _language = language, focusFirstWord: true);
      return;
    }
    setState(() {
      _language = language;
      _languageConfirmed = true;
      _needsLanguageChoice = false;
      _failure = null;
    });
  }

  /// Resolves a detected or ambiguous language from the notices: the words
  /// are valid in [language], so they stay.
  void _selectLanguage(bip39.Language language) {
    if (!_entryLanguages.contains(language)) return;
    if (_language != language) {
      log.config('Mnemonic language selected language=${language.name}');
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _language = language;
      _languageConfirmed = true;
      _needsLanguageChoice = false;
      _failure = null;
    });
  }

  /// The word count, as a segmented control across the page.
  Widget _lengthPicker(BuildContext context) {
    final labels = {
      for (final value in bip39.MnemonicLength.values) '${value.words}': value,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BullText(
          context.loc.mnemonicWordCountLabel,
          role: .caption,
          color: context.bull.textMuted,
        ),
        const Gap(6),
        SizedBox(
          width: double.infinity,
          child: BullSegmented(
            key: const Key('mnemonicLengthPicker'),
            items: labels.keys.toSet(),
            initialValue: '${length.words}',
            onSelected: (label) {
              final value = labels[label];
              if (value != null && value != length) changeMnemonicLength(value);
            },
          ),
        ),
      ],
    );
  }

  /// The notices that resolve the wordlist: a detected language, or the
  /// readings of an ambiguous phrase.
  Widget _buildLanguageSelection(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(_controllers),
      builder: (context, _) {
        final words = _words;
        // Ambiguity is a property of a complete phrase: a partial one shares
        // words between wordlists far too often to be worth announcing.
        final complete = words.every((word) => word.isNotEmpty);
        final readings = complete
            ? Bip39WordList.matchingLanguages(words, requireChecksum: true)
            : const <bip39.Language>[];
        final matches =
            (readings.isNotEmpty
                    ? readings
                    : Bip39WordList.matchingLanguages(words))
                .where(_entryLanguages.contains)
                .toList();
        final ambiguous =
            _needsLanguageChoice ||
            (readings.length > 1 && !_languageConfirmed);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ambiguous)
              Text(
                context.loc.mnemonicLanguageAmbiguous,
                style: context.bullType.body,
              ),
            if (matches.length == 1 && matches.single != _language)
              BullButton.secondary(
                label: context.loc.mnemonicLanguageSuggestion(
                  context.loc.mnemonicLanguageName(matches.single.name),
                ),
                onPressed: () => _selectLanguage(matches.single),
                size: BullButtonSize.small,
                compact: true,
              ),
            if (ambiguous)
              Wrap(
                children: [
                  for (final language in readings.where(
                    _entryLanguages.contains,
                  ))
                    BullButton.secondary(
                      label: context.loc.mnemonicLanguageName(language.name),
                      onPressed: () => _selectLanguage(language),
                      size: BullButtonSize.small,
                      compact: true,
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && passphrase.isNotEmpty) {
      setState(() {
        passphrase = '';
        _passphraseCleared = true;
        _passphraseGeneration++;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
  final ValueNotifier<MnemonicKeyboardBar?> _keyboardBarSlot = ValueNotifier(
    null,
  );

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
                  KeyedSubtree(
                    key: _languageNoticeKey,
                    child: _buildLanguageSelection(context),
                  ),
                  if (widget.allowMultipleMnemonicLength) ...[
                    const Gap(12),
                    _lengthPicker(context),
                  ],
                  const Gap(14),

                  MnemonicSentenceWidget(
                    controllers: _controllers,
                    language: _language,
                    allowAutoFillWords: widget.allowAutoFillWords,
                    keyboardBarSlot: _keyboardBarSlot,
                    onLanguageSelected: _chooseKeyboardLanguage,
                    focusFirstWordRequest: _focusFirstWordRequest,
                  ),

                  if (widget.allowPassphrase) ...[
                    const Gap(8),
                    // The whole row toggles, not just the switch.
                    MergeSemantics(
                      child: InkWell(
                        onTap: () => _setPassphraseEnabled(!_showPassphrase),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    BullText(
                                      context.loc.passphraseOption,
                                      style: context.bullType.body.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    BullText(
                                      _showPassphrase
                                          ? context
                                                .loc
                                                .passphraseOptionOnSubtitle
                                          : context
                                                .loc
                                                .passphraseOptionOffSubtitle,
                                      style: context.bullType.label.copyWith(
                                        fontWeight: FontWeight.w400,
                                      ),
                                      color: context.bull.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                              BullSwitch(
                                key: const Key('mnemonicPassphraseSwitch'),
                                value: _showPassphrase,
                                onChanged: _setPassphraseEnabled,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_showPassphrase) ...[
                      const Gap(8),
                      BullSecretTextInput(
                        key: ValueKey(_passphraseGeneration),
                        label: context.loc.passphraseLabel,
                        hint: context.loc.optionalPassphraseHint,
                        onChanged: updatePassphrase,
                        showLabel: context.loc.passphraseShow,
                        hideLabel: context.loc.passphraseHide,
                      ),
                      if (_passphraseCleared && passphrase.isEmpty) ...[
                        BullText(
                          context.loc.passphraseClearedNotice,
                          style: context.bullType.body,
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _passphraseCleared = false),
                          child: Text(context.loc.continueWithoutPassphrase),
                        ),
                      ],
                      if (passphrase != passphrase.trim())
                        BullText(
                          context.loc.passphraseWhitespaceWarning,
                          style: context.bullType.body,
                        ),
                    ],
                  ],

                  if (widget.allowLabel) ...[
                    const Gap(16),
                    BullLabeledTextInput(
                      label: context.loc.recipientsInfoLabel,
                      hint: context.loc.requiredHint,
                      value: label,
                      onChanged: updateLabel,
                      maxLines: 1,
                    ),
                  ],

                  if (errorMessage != null) ...[
                    const Gap(16),
                    BullText(
                      key: _errorKey,
                      errorMessage,
                      style: context.bullType.body,
                      color: context.bull.error,
                    ),
                  ],

                  const Gap(16),
                ],
              ),
            ),
          ),
        ),
        // Pinned under the page like the app's other actions: the submit
        // button while no word field is typed, the docked keyboard while one
        // is. Enter on the last word closes the keyboard and brings the
        // button back.
        ValueListenableBuilder<MnemonicKeyboardBar?>(
          valueListenable: _keyboardBarSlot,
          builder: (context, bar, _) {
            final submit = SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: BullButton.primary(
                  label: widget.submitLabel ?? context.loc.submitButton,
                  onPressed: onSubmit,
                ),
              ),
            );
            if (bar == null) return submit;
            return ValueListenableBuilder<int?>(
              valueListenable: bar.activeField,
              builder: (context, active, _) =>
                  active == null ? submit : bar.build(context),
            );
          },
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
/// the in-app [BullMnemonicKeyboard], so the recovery phrase never travels through
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
    required this.language,
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
      padding: const EdgeInsets.only(left: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.bullShapes.input),
        border: Border.all(color: context.bull.border),
        color: context.bull.surface,
      ),
      // A floor, not a height: the field grows with the system text size.
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: [
          ListenableBuilder(
            listenable: candidates == null
                ? controller
                : Listenable.merge([controller, ?candidates]),
            builder: (context, _) {
              final word = Bip39WordList.normalize(controller.text);
              // With a candidate pool (last field), acceptability means
              // closing the checksum; without one, plain wordlist membership.
              final pool = candidates?.value;
              final isValid = pool != null
                  ? pool.any((entry) => Bip39WordList.normalize(entry) == word)
                  : language.isValid(word);
              return Container(
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: word.isEmpty
                      ? context.bull.onSurface
                      : isValid
                      ? context.bull.success
                      : context.bull.error,
                  borderRadius: BorderRadius.circular(context.bullShapes.badge),
                ),
                child: BullText(
                  displayIndex,
                  role: .body,
                  fontWeight: .w700,
                  color: context.bull.surface,
                ),
              );
            },
          ),
          const Gap(8),
          Expanded(
            // Read-only: the platform keyboard never opens, paste and the
            // selection toolbar are suppressed. The only writer of this
            // controller is the in-app BullMnemonicKeyboard, so no keystroke of
            // the seed leaves the app process.
            child: TextField(
              readOnly: true,
              showCursor: true,
              enableInteractiveSelection: false,
              contextMenuBuilder: (_, _) => const SizedBox.shrink(),
              enableSuggestions: false,
              autocorrect: false,
              controller: controller,
              style: context.bullType.body.copyWith(color: context.bull.text),
              focusNode: focusNode,
              clipBehavior: .antiAliasWithSaveLayer,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.only(right: 8),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: context.bull.transparent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: context.bull.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: context.bull.transparent),
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
                icon: Icon(Icons.close, size: 18, color: context.bull.text),
                padding: EdgeInsets.zero,
                // Within the field's floor, border included: Material's 48 dp
                // tap target would push a field with a word taller than its
                // neighbours.
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 36,
                ),
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
  final ValueNotifier<MnemonicKeyboardBar?>? keyboardBarSlot;

  /// The keyboard's language key, with the field being typed. Null hides it.
  final void Function(bip39.Language language, int? typing)? onLanguageSelected;

  /// Changed together with [controllers] when the new fields should open on
  /// the first word, keyboard up.
  final int focusFirstWordRequest;

  const MnemonicSentenceWidget({
    super.key,
    required this.controllers,
    required this.language,
    this.allowAutoFillWords = true,
    this.keyboardBarSlot,
    this.onLanguageSelected,
    this.focusFirstWordRequest = 0,
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

  /// Paranoid mode: the keyboard shows a randomised layout instead of the
  /// national one. Toggled by the shuffle button.
  final ValueNotifier<bool> _paranoid = ValueNotifier(false);

  /// The current randomised orders, regenerated on every key tap while
  /// paranoid so a key never sits in the same place twice — nothing can be
  /// learned from watching finger positions or a screen recording. The letter
  /// rows and the accent page are fixed key sets; a grid's keys change with
  /// the prefix, so its order is redrawn once the next keys are known.
  List<String>? _shuffledKeys;
  List<String>? _shuffledAccents;
  List<String>? _shuffledGrid;
  bool _gridStale = true;
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
      if (mounted) {
        widget.keyboardBarSlot?.value = (
          activeField: _activeField,
          build: _buildKeyboardBar,
        );
      }
    });
  }

  @override
  void didUpdateWidget(MnemonicSentenceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) {
      _revision++;
      _shuffledKeys = null;
      _shuffledAccents = null;
      _shuffledGrid = null;
      _gridStale = true;
      _candidatesKey = null;
      _shuffledHintsFor = null;
      _shuffledHintsOrder = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _candidatePool.value = _lastWordCandidates();
        _refreshHint(_hint.value.index, force: true);
      });
    }
    if (!identical(oldWidget.controllers, widget.controllers)) {
      _revision++;
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
      final focusFirst =
          widget.focusFirstWordRequest != oldWidget.focusFirstWordRequest;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _activeField.value = null;
        _candidatePool.value = null;
        _hint.value = (index: 0, prefix: '', revision: ++_revision);
        if (focusFirst && _focusNodes.isNotEmpty) {
          _focusNodes.first.requestFocus();
        }
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
    _revision++;
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
    _revision++;
    // The pool is derived from every word but the last; the cached answer is
    // a new instance only when it actually changed.
    final pool = _lastWordCandidates();
    if (!identical(pool, _candidatePool.value)) {
      _candidatePool.value = pool;
    }
    final hinted = _hint.value.index;
    // Any edit invalidates callbacks captured for the previous phrase.
    _refreshHint(hinted);
    _maybeAutoFill(index);
  }

  /// Cached: the answer only changes when a word other than the last does,
  /// so typing in the last field does not recompute it.
  List<String>? _lastWordCandidates() {
    final previous = [
      for (var i = 0; i < widget.controllers.length - 1; i++)
        Bip39WordList.normalize(widget.controllers[i].text),
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
      prefix: Bip39WordList.normalize(widget.controllers[index].text),
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
    final prefix = Bip39WordList.normalize(widget.controllers[index].text);
    if (prefix.isEmpty) return;

    // Stop at the second match: only ambiguity matters here, not the count.
    final matches = widget.language.list
        .where((word) => Bip39WordList.normalize(word).startsWith(prefix))
        .take(2)
        .toList();
    if (matches.length == 1 &&
        Bip39WordList.normalize(matches.first) != prefix) {
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
    final prefix = Bip39WordList.normalize(widget.controllers[index].text);
    final allowed = Bip39WordList.allowedNextKeys(
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
    final layout = MnemonicKeyboardLayout.of(widget.language);
    if (layout.grid) {
      _gridStale = true;
      return;
    }
    _shuffledKeys = _scramble(layout.keys, _shuffledKeys);
    _shuffledAccents = _scramble(layout.accents, _shuffledAccents);
  }

  /// A fresh order of [keys] through the kit policy (see BullKeyScramble):
  /// compared with [previous] when it holds the same keys, with the natural
  /// order otherwise, so no key sits where the eye expects it.
  List<String> _scramble(List<String> keys, List<String>? previous) {
    if (keys.isEmpty) return keys;
    final sameKeys =
        previous != null &&
        previous.length == keys.length &&
        previous.toSet().containsAll(keys);
    return BullKeyScramble.next(
      keys,
      previous: sameKeys ? previous : keys,
      maxUnmoved: _maxUnmoved(keys.length),
      random: _random,
    );
  }

  /// Six of the 26 letters may stay in place; a handful of keys is shuffled
  /// freely, since forcing every key to move would make the order predictable.
  static int _maxUnmoved(int count) =>
      count <= 4 ? count : max(1, count * 6 ~/ 26);

  /// The grid's keys in a scrambled order, redrawn once per tap.
  List<String> _scrambledGrid(List<String> keys) {
    final current = _shuffledGrid;
    final sameKeys =
        current != null &&
        current.length == keys.length &&
        current.toSet().containsAll(keys);
    if (current == null || _gridStale || !sameKeys) {
      _gridStale = false;
      return _shuffledGrid = _scramble(keys, current);
    }
    return current;
  }

  /// The docked bottom bar: the in-app keyboard with its suggestion strip,
  /// like a system keyboard, so neither the suggestions nor a focused field
  /// is ever hidden behind it. Empty until a word field is focused. Rendered
  /// by the parent below the scroll area (via
  /// [MnemonicSentenceWidget.keyboardBarSlot]).
  ///
  /// [ExcludeFocus] keeps every tap target here out of focus traversal: the
  /// keys and suggestions must never steal focus from the word field being
  /// typed into.
  Widget _buildKeyboardBar(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_activeField, _paranoid]),
      builder: (context, _) {
        if (_activeField.value == null) return const SizedBox.shrink();
        return TextFieldTapRegion(child: ExcludeFocus(child: _buildKeyboard()));
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
        if (query.index >= widget.controllers.length) {
          return const SizedBox.shrink();
        }
        final language = widget.language;
        final controller = widget.controllers[query.index];
        final prefix = query.prefix;
        final paranoid = _paranoid.value;
        final layout = MnemonicKeyboardLayout.of(language);
        final allowed = Bip39WordList.allowedNextKeys(
          prefix: prefix,
          language: language,
        );
        List<String> keys;
        var accents = layout.accents;
        if (layout.grid) {
          final ordered = Bip39WordList.orderedNextLetters(
            prefix: prefix,
            language: language,
          );
          keys = paranoid ? _scrambledGrid(ordered) : ordered;
        } else if (paranoid) {
          keys = _shuffledKeys ??= _scramble(layout.keys, null);
          accents = _shuffledAccents ??= _scramble(layout.accents, null);
        } else {
          keys = layout.keys;
        }
        final (:suggestions, :notice) = _suggestionsFor(
          query,
          paranoid: paranoid,
        );
        final onLanguageSelected = widget.onLanguageSelected;
        return BullMnemonicKeyboard(
          scrollable: layout.grid,
          layout: keys,
          rows: layout.rows,
          accents: accents,
          variants: layout.grid
              ? const {}
              : MnemonicKeyboardLayout.variantsOf(
                  accents: accents,
                  allowed: allowed,
                ),
          enabledLetters: allowed,
          canBackspace: prefix.isNotEmpty,
          canAdvance: _canLeaveField(prefix),
          onLetter: (letter) {
            if (_isCurrentQuery(query, language, controller)) {
              _onKeyLetter(letter);
            }
          },
          onBackspace: () {
            if (_isCurrentQuery(query, language, controller)) _onKeyBackspace();
          },
          onEnter: () {
            if (_isCurrentQuery(query, language, controller)) _onKeyEnter();
          },
          shuffleActive: paranoid,
          onToggleShuffle: _toggleParanoid,
          shuffleHint: context.loc.mnemonicShuffleKeyboardHint,
          suggestions: suggestions,
          suggestionNotice: notice,
          onSuggestion: (word) => _onHintTap(query, language, controller, word),
          languages: [
            for (final entry in _entryLanguages)
              BullKeyboardLanguage(
                code: _languageCode(entry),
                name: context.loc.mnemonicLanguageName(entry.name),
              ),
          ],
          selectedLanguage: _entryLanguages.indexOf(language),
          onLanguage: onLanguageSelected == null
              ? null
              : (index) => onLanguageSelected(
                  _entryLanguages[index],
                  _activeField.value,
                ),
          languageHint: context.loc.mnemonicLanguageLabel,
        );
      },
    );
  }

  /// Up to three words for the strip, best first: the shortest words the
  /// prefix leads to, a short word being the one auto fill can never complete.
  /// Nothing before the first letter, and nothing for Chinese, whose words
  /// are single characters typed in one tap. On the last field, the count of
  /// checksum candidates stands in while the field is empty.
  ({List<String> suggestions, String? notice}) _suggestionsFor(
    _HintQuery query, {
    required bool paranoid,
  }) {
    final isLastWord = query.index == widget.controllers.length - 1;
    // Null means the question does not apply - an earlier word is missing
    // or unknown - which is exactly the signal for falling back.
    final candidates = isLastWord ? _lastWordCandidates() : null;
    final pool = candidates ?? widget.language.list;
    final chinese =
        widget.language == bip39.Language.simplifiedChinese ||
        widget.language == bip39.Language.traditionalChinese;
    if (query.prefix.isEmpty || chinese) {
      return (
        suggestions: const <String>[],
        notice: candidates != null && query.prefix.isEmpty
            ? context.loc.mnemonicPossibleLastWords(pool.length)
            : null,
      );
    }
    final matches = [
      for (final (index, word) in pool.indexed)
        if (Bip39WordList.normalize(word).startsWith(query.prefix))
          (
            index: index,
            word: word,
            length: Bip39WordList.normalize(word).length,
          ),
    ];
    // The field already holds the single matching word: the question is
    // answered, so the strip empties.
    if (matches.length == 1 &&
        Bip39WordList.normalize(matches.single.word) == query.prefix) {
      return (suggestions: const <String>[], notice: null);
    }
    matches.sort(
      (a, b) => a.length != b.length
          ? a.length.compareTo(b.length)
          : a.index.compareTo(b.index),
    );
    final best = [for (final match in matches.take(3)) match.word];
    if (!paranoid) return (suggestions: best, notice: null);
    // Paranoid mode randomises the order so a position leaks nothing about
    // which word it is. Cached per _hint query (which bumps once per
    // keystroke) so the order is stable across unrelated rebuilds.
    final cached = _shuffledHintsOrder;
    if (query != _shuffledHintsFor || cached == null) {
      best.shuffle(_random);
      _shuffledHintsFor = query;
      _shuffledHintsOrder = best;
      return (suggestions: best, notice: null);
    }
    return (suggestions: cached, notice: null);
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
  bool _isWholeWord(String word) =>
      widget.language.isValid(Bip39WordList.normalize(word));

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

  bool _isCurrentQuery(
    _HintQuery query,
    bip39.Language language,
    TextEditingController controller,
  ) {
    final index = query.index;
    return mounted &&
        widget.language == language &&
        _revision == query.revision &&
        _activeField.value == index &&
        index >= 0 &&
        index < widget.controllers.length &&
        identical(widget.controllers[index], controller) &&
        Bip39WordList.normalize(controller.text) == query.prefix;
  }

  void _onHintTap(
    _HintQuery query,
    bip39.Language language,
    TextEditingController controller,
    String word,
  ) {
    final normalized = Bip39WordList.normalize(word);
    if (!_isCurrentQuery(query, language, controller) ||
        !language.isValid(normalized) ||
        !normalized.startsWith(query.prefix)) {
      return;
    }
    final index = query.index;
    _setWord(index, word);
    // Like the auto fill, a tapped chip completes the sentence on the last
    // field: the same natural moment to dismiss the keyboard.
    if (index == widget.controllers.length - 1) {
      _focusNodes[index].unfocus();
    } else {
      _focusNext(index + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.controllers.length;
    final splitIndex = (count / MnemonicSentenceWidget.columns).floor();

    Widget column(int from, int to) => Column(
      spacing: 8,
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
