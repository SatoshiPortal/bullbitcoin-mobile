import 'dart:async';

import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/experimental/mnemonic_translate/domain/usecases/get_default_mnemonic_usecase.dart';
import 'package:bb_mobile/features/experimental/mnemonic_translate/mnemonic_translate_cubit.dart';
import 'package:bb_mobile/features/experimental/mnemonic_translate/mnemonic_translate_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class MnemonicTranslatePage extends StatefulWidget {
  const MnemonicTranslatePage({super.key});

  @override
  State<MnemonicTranslatePage> createState() => _MnemonicTranslatePageState();
}

class _MnemonicTranslatePageState extends State<MnemonicTranslatePage>
    with PrivacyScreen {
  @override
  void initState() {
    super.initState();
    enableScreenPrivacy();
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) => MnemonicTranslateCubit(
            getDefaultMnemonicUsecase: locator<GetDefaultMnemonicUsecase>(),
          ),
      child: const _MnemonicTranslateView(),
    );
  }
}

class _MnemonicTranslateView extends StatelessWidget {
  const _MnemonicTranslateView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colour.secondaryFixed,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Mnemonic Translator',
          color: context.colour.secondaryFixed,
          onBack: () => context.pop(),
        ),
      ),
      body: BlocBuilder<MnemonicTranslateCubit, MnemonicTranslateState>(
        builder: (context, state) {
          final cubit = context.read<MnemonicTranslateCubit>();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MnemonicDisplay(words: state.translatedMnemonic),
                const Gap(16),
                if (state.passphrase != null)
                  _PassphraseDisplay(passphrase: state.passphrase!),
                if (state.error != null) ...[
                  const Gap(8),
                  Text(
                    'Error: ${state.error}',
                    style: context.font.bodyMedium?.copyWith(
                      color: context.colour.error,
                    ),
                  ),
                ],
                const Expanded(child: SizedBox()),
                SizedBox(
                  height: 56,
                  child: Material(
                    elevation: 4,
                    color: context.colour.onPrimary,
                    borderRadius: BorderRadius.circular(4.0),
                    child: Center(
                      child: DropdownButtonFormField<bip39.Language>(
                        alignment: Alignment.centerLeft,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                          ),
                        ),
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: context.colour.secondary,
                        ),
                        value: state.selectedLanguage,
                        items:
                            state.languages
                                .map(
                                  (language) =>
                                      DropdownMenuItem<bip39.Language>(
                                        value: language,
                                        child: BBText(
                                          _getLanguageDisplayName(language),
                                          style: context.font.headlineSmall,
                                        ),
                                      ),
                                )
                                .toList(),
                        onChanged: cubit.onLanguageChanged,
                      ),
                    ),
                  ),
                ),
                const Gap(32),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getLanguageDisplayName(bip39.Language language) {
    switch (language) {
      case bip39.Language.english:
        return '🇺🇸 English';
      case bip39.Language.french:
        return '🇫🇷 French';
      case bip39.Language.spanish:
        return '🇪🇸 Spanish';
      case bip39.Language.italian:
        return '🇮🇹 Italian';
      case bip39.Language.portuguese:
        return '🇵🇹 Portuguese';
      case bip39.Language.czech:
        return '🇨🇿 Czech';
      case bip39.Language.japanese:
        return '🇯🇵 Japanese';
      case bip39.Language.korean:
        return '🇰🇷 Korean';
      case bip39.Language.simplifiedChinese:
        return '🇨🇳 Chinese (Simplified)';
      case bip39.Language.traditionalChinese:
        return '🇹🇼 Chinese (Traditional)';
    }
  }
}

class _MnemonicDisplay extends StatelessWidget {
  const _MnemonicDisplay({required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colour.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          if (words.length == 12) ...[
            for (var i = 0; i < 6; i++)
              Row(
                children: [
                  _MnemonicWord(index: i, number: i + 1, word: words[i]),
                  const Gap(8),
                  _MnemonicWord(
                    index: i + 6,
                    number: i + 7,
                    word: words[i + 6],
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _PassphraseDisplay extends StatelessWidget {
  const _PassphraseDisplay({required this.passphrase});

  final String passphrase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colour.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colour.surface, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            'Passphrase',
            style: context.font.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colour.surface,
              letterSpacing: 0,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: BBText(
              passphrase,
              style: context.font.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: context.colour.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MnemonicWord extends StatelessWidget {
  const _MnemonicWord({
    required this.index,
    required this.number,
    required this.word,
  });

  final int index;
  final int number;
  final String word;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: context.colour.onPrimary,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: context.colour.surface),
        ),
        height: 41,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              flex: 2,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.colour.secondary,
                  border: Border.all(color: context.colour.secondary),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: BBText(
                    number < 10 ? '0$number' : '$number',
                    style: context.font.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: context.colour.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const Gap(8),
            Expanded(
              flex: 6,
              child: BBText(
                word,
                textAlign: TextAlign.start,
                maxLines: 1,
                style: context.font.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: context.colour.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
