import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';

class MnemonicLanguageDropdown extends StatelessWidget {
  final bip39.Language selectedLanguage;
  final ValueChanged<bip39.Language> onChanged;

  const MnemonicLanguageDropdown({
    super.key,
    required this.selectedLanguage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.colour.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colour.outline),
      ),
      child: DropdownButtonFormField<bip39.Language>(
        alignment: Alignment.centerLeft,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
        ),
        icon: Icon(Icons.keyboard_arrow_down, color: context.colour.secondary),
        value: selectedLanguage,
        items:
            bip39.Language.values
                .map(
                  (language) => DropdownMenuItem<bip39.Language>(
                    value: language,
                    child: BBText(
                      _getLanguageDisplayName(language),
                      style: context.font.bodyMedium,
                    ),
                  ),
                )
                .toList(),
        onChanged: (language) {
          if (language != null) onChanged(language);
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
