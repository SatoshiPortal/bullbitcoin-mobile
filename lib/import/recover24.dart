import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/components/utils.dart';
import 'package:bb_mobile/import/bloc/import_cubit.dart';
import 'package:bb_mobile/import/bloc/import_state.dart';
import 'package:bb_mobile/import/bloc/words_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ImportEnterWordsScreen24 extends StatelessWidget {
  ImportEnterWordsScreen24({super.key});

  final focusNodes = List<FocusNode>.generate(24, (index) => FocusNode());

  void returnClicked(int idx) {
    if (idx == 23) return;
    focusNodes[idx + 1].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    const ImportTypes importwords = ImportTypes.words24;

    return Scrollbar(
      interactive: true,
      thumbVisibility: false,
      thickness: 5,
      radius: const Radius.circular(4),
      scrollbarOrientation: ScrollbarOrientation.right,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap(22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: SegmentedButton(
                  style: ButtonStyle(
                    iconColor: MaterialStatePropertyAll<Color>(
                      context.colour.onBackground,
                    ),
                    backgroundColor: MaterialStatePropertyAll<Color>(
                      context.colour.background,
                    ),
                  ),
                  segments: <ButtonSegment<ImportTypes>>[
                    ButtonSegment(
                      value: ImportTypes.words12,
                      label: Text(
                        '12 words',
                        style: TextStyle(
                          color: context.colour.onBackground,
                        ),
                      ),
                    ),
                    ButtonSegment(
                      value: ImportTypes.words24,
                      label: Text(
                        '24 words',
                        style: TextStyle(
                          color: context.colour.onBackground,
                        ),
                      ),
                    ),
                  ],
                  selected: const <ImportTypes>{
                    importwords,
                  },
                  onSelectionChanged: (p0) {
                    context.read<ImportWalletCubit>().recoverClicked();
                  },
                ),
              ),
              const Gap(25),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = 0; i < 12; i++)
                          ImportWordTextField(
                            index: i,
                            focusNode: focusNodes[i],
                            returnClicked: returnClicked,
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = 12; i < 24; i++)
                          ImportWordTextField(
                            index: i,
                            focusNode: focusNodes[i],
                            returnClicked: returnClicked,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(32),
              const _ImportWordsPassphrase(),
              const Gap(32),
              const _WalletLabel(),
              const Gap(55),
              const _ImportWordsRecoverButton(),
            ],
          ),
        ),
      ).animate(delay: 200.ms).fadeIn(),
    );
  }
}

class ImportWordTextField extends StatefulWidget {
  const ImportWordTextField({
    super.key,
    required this.index,
    required this.focusNode,
    required this.returnClicked,
  });

  final int index;
  final FocusNode focusNode;
  final Function(int) returnClicked;

  @override
  State<ImportWordTextField> createState() => _ImportWordTextFieldState();
}

class _ImportWordTextFieldState extends State<ImportWordTextField> {
  OverlayEntry? entry;
  final layerLink = LayerLink();
  final controller = TextEditingController();
  List<String> suggestions = [];
  bool tapped = false;

  @override
  void initState() {
    super.initState();

    widget.focusNode.addListener(() {
      if (widget.focusNode.hasFocus) {
        showOverLay();
      } else
        hideOverlay();
    });

    controller.addListener(() {
      // if (suggestions.isNotEmpty && suggestions.contains(controller.text)) return;

      hideOverlay();
      setState(() {
        suggestions = context.read<WordsCubit>().state.findWords(controller.text);
      });
      if (tapped) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showOverLay();
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    widget.focusNode.dispose();

    super.dispose();
  }

  void showOverLay() {
    print('Show overlay');
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject()! as RenderBox;
    final size = renderBox.size;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 24,
        child: CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          offset: Offset(24, size.height - 8),
          child: buildOverlay(),
        ),
      ),
    );

    overlay.insert(entry!);
  }

  void hideOverlay() {
    print('Hide overlay');
    entry?.remove();
    entry = null;
  }

  Widget buildOverlay() {
    if (suggestions.isEmpty) {
      hideOverlay();
      return Container();
    }

    return Material(
      elevation: 2,
      shadowColor: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          for (final word in suggestions)
            ListTile(
              title: BBText.body(word),
              onTap: () {
                context.read<ImportWalletCubit>().wordChanged24(widget.index, word, true);
                hideOverlay();
                setState(() {
                  tapped = true;
                });
                widget.focusNode.unfocus();
                widget.returnClicked(widget.index);
              },
            ),
        ],
      ),
    );
  }

  void onSubmit(String value) {
    final suggestions = context.read<WordsCubit>().state.findWords(value);
    hideOverlay();
    if (suggestions.isNotEmpty && suggestions.contains(value)) {
      context.read<ImportWalletCubit>().wordChanged24(widget.index, value, true);
      setState(() {
        tapped = true;
      });
    } else {
      context.read<ImportWalletCubit>().wordChanged24(widget.index, '', false);
      controller.clear();
    }
    widget.focusNode.unfocus();
    widget.returnClicked(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    final word = context.select(
      (ImportWalletCubit cubit) => cubit.state.words24.elementAtOrNull(widget.index),
    );

    if (word == null) return const SizedBox.shrink();
    if (controller.text != word.word) controller.text = word.word;

    return CompositedTransformTarget(
      link: layerLink,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        height: 45,
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: BBText.body(
                '${widget.index + 1}',
                textAlign: TextAlign.right,
              ),
            ),
            const Gap(5),
            Expanded(
              child: CallbackShortcuts(
                bindings: {
                  LogicalKeySet(LogicalKeyboardKey.enter): () {
                    if (widget.focusNode.hasFocus) widget.returnClicked(widget.index);
                  },
                },
                child: AnimatedOpacity(
                  duration: 200.ms,
                  opacity: !word.tapped ? 0.5 : 1,
                  child: BBTextInput.small(
                    focusNode: widget.focusNode,
                    controller: controller,
                    onEnter: () {
                      context.read<ImportWalletCubit>().clearUntappedWords();
                    },
                    onChanged: (value) {
                      context.read<ImportWalletCubit>().wordChanged24(widget.index, value, false);
                      hideOverlay();
                      setState(() {
                        tapped = false;
                      });
                    },
                    value: word.word,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (String value) => onSubmit(value),
                  ),
                ),
              ),
              // ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportWordsPassphrase extends StatelessWidget {
  const _ImportWordsPassphrase();

  @override
  Widget build(BuildContext context) {
    final text = context.select((ImportWalletCubit cubit) => cubit.state.passPhrase);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: BBTextInput.big(
        value: text,
        onChanged: (value) => context.read<ImportWalletCubit>().passPhraseChanged(value),
        hint: 'Enter passphrase if needed',
      ),
    );
  }
}

class _WalletLabel extends StatelessWidget {
  const _WalletLabel();

  @override
  Widget build(BuildContext context) {
    final text = context.select((ImportWalletCubit cubit) => cubit.state.walletLabel ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: BBTextInput.big(
        value: text,
        onChanged: (value) => context.read<ImportWalletCubit>().walletLabelChanged(value),
        hint: 'Label your wallet',
      ),
    );
  }
}

class _ImportWordsRecoverButton extends StatelessWidget {
  const _ImportWordsRecoverButton();

  @override
  Widget build(BuildContext context) {
    final ImportWalletCubit cubit = context.select((ImportWalletCubit cubit) => cubit);
    final recovering = context.select((ImportWalletCubit cubit) => cubit.state.importing);
    final err = context.select((ImportWalletCubit cubit) => cubit.state.errImporting);

    if (err.isNotEmpty) {
      showErrorAlert(context, err, cubit);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          if (err.isNotEmpty) ...[
            const Gap(8),
            BBText.error(
              err,
            ),
          ],
          SizedBox(
            width: 250,
            child: BBButton.bigRed(
              label: 'Recover',
              onPressed: () {
                context.read<ImportWalletCubit>().recoverWallet24Clicked();
              },
              disabled: recovering,
            ),
          ),
          const Gap(18),
        ],
      ),
    );
  }
}
