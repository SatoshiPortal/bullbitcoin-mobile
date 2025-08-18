import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

typedef Mnemonic =
    ({
      String label,
      String passphrase,
      List<String> words,
      bip39.Language language,
    });

class MnemonicWidget extends StatefulWidget {
  final bip39.Language language;
  final bip39.MnemonicLength initialLength;
  final Function(Mnemonic) onSubmit;
  final String submitLabel;
  final bool allowPassphrase;
  final bool allowLabel;
  final bool allowMultipleMnemonicLength;
  final bool allowAutoFillWords;

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
  });

  @override
  State<MnemonicWidget> createState() => _MnemonicWidgetState();
}

class _MnemonicWidgetState extends State<MnemonicWidget> {
  Exception? _error;
  late bip39.MnemonicLength length;
  late List<String> words;
  String passphrase = '';
  String label = '';

  @override
  void initState() {
    super.initState();
    length = widget.initialLength;
    words = List<String>.filled(length.words, '');
  }

  void onSubmit() {
    setState(() => _error = null);

    if (words.every((word) => word.isNotEmpty)) {
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
        // if checksum is invalid, clear the last word
        if (e is bip39.MnemonicInvalidChecksumException) words.last = '';
        setState(() => _error = MnemonicException(e.toString()));
        return;
      }
    } else {
      setState(() => _error = EmptyMnemonicWordsError());
    }
  }

  void updateMnemonic(({int index, String word}) value) {
    words[value.index] = value.word;
    setState(() {});
  }

  void updatePassphrase(String value) {
    passphrase = value;
    setState(() {});
  }

  void updateLabel(String value) {
    label = value;
    setState(() {});
  }

  void changeMnemonicLength(bip39.MnemonicLength length) {
    this.length = length;
    words = List<String>.filled(length.words, '');
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
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
            words: words,
            language: widget.language,
            onWordChanged: updateMnemonic,
            allowAutoFillWords: widget.allowAutoFillWords,
          ),

          if (widget.allowPassphrase) ...[
            const Gap(16),
            SingleLineTextWidget(
              label: 'Passphrase',
              hint: 'Optional Passphrase',
              value: passphrase,
              onChanged: updatePassphrase,
            ),
          ],

          if (widget.allowLabel) ...[
            const Gap(16),
            SingleLineTextWidget(
              label: 'Label',
              hint: 'Required',
              value: label,
              onChanged: updateLabel,
            ),
          ],

          if (_error != null) ...[
            const Gap(16),
            BBText(
              _error!.toString(),
              style: context.font.bodyMedium,
              color: context.colour.onError,
            ),
          ],

          const Gap(16),
          BBButton.big(
            label: widget.submitLabel,
            onPressed: onSubmit,
            bgColor: context.colour.secondary,
            textColor: context.colour.onPrimary,
          ),
        ],
      ),
    );
  }
}

class MnemonicWord extends StatefulWidget {
  final bip39.Language language;
  final int index;
  final Function(({int index, String word})) onWordChanged;
  final FocusNode focusNode;
  final VoidCallback onComplete;
  final String word;

  const MnemonicWord({
    this.language = bip39.Language.english,
    required this.index,
    required this.word,
    required this.onWordChanged,
    required this.focusNode,
    required this.onComplete,
  });

  @override
  State<MnemonicWord> createState() => MnemonicWordState();
}

class MnemonicWordState extends State<MnemonicWord> {
  final _controller = TextEditingController();

  String get displayIndex {
    final displayIndex = widget.index + 1;
    return displayIndex < 10 ? '0$displayIndex' : '$displayIndex';
  }

  @override
  Widget build(BuildContext context) {
    final isValidWord = widget.language.isValid(widget.word);
    _controller.text = widget.word;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.colour.secondary),
        color: context.colour.onPrimary,
      ),
      height: 41,
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  widget.word.isEmpty
                      ? context.colour.secondary
                      : isValidWord
                      ? Colors.green
                      : Colors.red,

              borderRadius: BorderRadius.circular(4),
            ),
            child: BBText(
              displayIndex,
              style: context.font.headlineMedium,
              color: context.colour.onPrimary,
              textAlign: TextAlign.right,
            ),
          ),
          const Gap(4),
          Expanded(
            child: TextField(
              enableSuggestions: false,
              autocorrect: false,
              controller: _controller,
              onChanged: (value) {
                widget.onWordChanged((
                  index: widget.index,
                  word: _controller.text,
                ));
              },
              focusNode: widget.focusNode,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              onEditingComplete: widget.onComplete,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.only(right: 8),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.transparent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.transparent),
                ),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty || isValidWord)
            IconButton(
              onPressed: () {
                _controller.clear();
                widget.onWordChanged((index: widget.index, word: ''));
              },
              icon: const Icon(Icons.close, size: 24),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

class MnemonicSentenceWidget extends StatefulWidget {
  static const int columns = 2;
  final List<String> words;
  final bip39.Language language;
  final Function(({int index, String word})) onWordChanged;
  final bool allowAutoFillWords;

  const MnemonicSentenceWidget({
    super.key,
    required this.words,
    required this.language,
    required this.onWordChanged,
    this.allowAutoFillWords = true,
  });

  @override
  State<MnemonicSentenceWidget> createState() => _MnemonicSentenceWidgetState();
}

class _MnemonicSentenceWidgetState extends State<MnemonicSentenceWidget> {
  List<FocusNode> focusNodes = [];
  int _focusedDisplayIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeFocusNodes();
  }

  @override
  void didUpdateWidget(MnemonicSentenceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.words.length != widget.words.length) {
      _disposeFocusNodes();
      _initializeFocusNodes();
      _focusedDisplayIndex = 0;
    }
  }

  @override
  void dispose() {
    _disposeFocusNodes();
    super.dispose();
  }

  void _initializeFocusNodes() {
    focusNodes = List.generate(
      widget.words.length,
      (index) =>
          FocusNode()..addListener(() {
            final focusedIndex = focusNodes.indexWhere((node) => node.hasFocus);
            if (focusedIndex != -1 && _focusedDisplayIndex != focusedIndex) {
              setState(() => _focusedDisplayIndex = focusedIndex);
            }
          }),
    );
  }

  void _disposeFocusNodes() {
    for (final node in focusNodes) {
      node.dispose();
    }
    focusNodes.clear();
  }

  void _focusNext(int nextIndex) {
    if (nextIndex < widget.words.length) {
      if (nextIndex >= 0 && nextIndex < focusNodes.length) {
        FocusScope.of(context).requestFocus(focusNodes[nextIndex]);
      }
    }
  }

  void _onHintTap(String word) {
    widget.onWordChanged((index: _focusedDisplayIndex, word: word));
    _focusNext(_focusedDisplayIndex + 1);
  }

  Widget _buildHintsList({Key? key}) {
    const height = 50.0;
    final hints = widget.language.list.where(
      (word) => word.startsWith(widget.words[_focusedDisplayIndex]),
    );

    if (widget.allowAutoFillWords && hints.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _onHintTap(hints.first),
      );
    }

    if (hints.length == 1 &&
        hints.first == widget.words[_focusedDisplayIndex]) {
      return const SizedBox(height: height);
    }

    return SizedBox(
      key: key,
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hints.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final hint = hints.elementAt(index);
          return _HintChip(word: hint, onTap: () => _onHintTap(hint));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final splitIndex =
        (widget.words.length / MnemonicSentenceWidget.columns).floor();
    final leftWords = List.generate(
      splitIndex,
      (i) => (index: i, word: widget.words[i]),
    );
    final rightWords = List.generate(
      widget.words.length - splitIndex,
      (i) => (index: i + splitIndex, word: widget.words[i + splitIndex]),
    );

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Expanded(
              child: Column(
                spacing: 16,
                children:
                    leftWords
                        .map(
                          (entry) => MnemonicWord(
                            index: entry.index,
                            word: entry.word,
                            onWordChanged: widget.onWordChanged,
                            focusNode: focusNodes[entry.index],
                            onComplete: () => _focusNext(entry.index + 1),
                          ),
                        )
                        .toList(),
              ),
            ),
            Expanded(
              child: Column(
                spacing: 16,
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    rightWords
                        .map(
                          (entry) => MnemonicWord(
                            index: entry.index,
                            word: entry.word,
                            onWordChanged: widget.onWordChanged,
                            focusNode: focusNodes[entry.index],
                            onComplete: () => _focusNext(entry.index + 1),
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ),
        const Gap(16),
        _buildHintsList(key: ValueKey(_focusedDisplayIndex)),
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
        fontWeight: FontWeight.w600,
        color: context.colour.secondary,
      ),
      dropdownColor: context.colour.onPrimary,
      borderRadius: BorderRadius.circular(4),
      items:
          bip39.MnemonicLength.values
              .map(
                (length) => DropdownMenuItem(
                  value: length,
                  child: BBText(
                    '${length.words} words',
                    style: context.font.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colour.secondary,
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
          color: context.colour.onPrimary,
          border: Border.all(color: context.colour.surface),
        ),
        child: Center(child: BBText(word, style: context.font.bodyLarge)),
      ),
    );
  }
}

class SingleLineTextWidget extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final Function(String) onChanged;

  const SingleLineTextWidget({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          label,
          style: context.font.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colour.secondary,
            letterSpacing: 0,
            fontSize: 14,
          ),
        ),
        const Gap(8),
        Container(
          decoration: BoxDecoration(
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(2.76),
            border: Border.all(color: context.colour.surface, width: 0.69),
            boxShadow: [
              BoxShadow(
                color: context.colour.surface,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: BBInputText(
            value: value,
            onChanged: onChanged,
            style: context.font.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: context.colour.secondary,
            ),
            hintStyle: context.font.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: context.colour.surface,
            ),
            hint: hint,
            hideBorder: true,
          ),
        ),
      ],
    );
  }
}

class MnemonicException implements Exception {
  final String message;

  MnemonicException(this.message);

  @override
  String toString() => message;
}

class EmptyMnemonicWordsError extends MnemonicException {
  EmptyMnemonicWordsError() : super('Enter all words of your mnemonic');
}
