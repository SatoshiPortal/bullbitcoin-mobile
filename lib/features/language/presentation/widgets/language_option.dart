import 'package:bb_mobile/features/language/domain/entities/language.dart';
import 'package:bb_mobile/features/language/presentation/bloc/language_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LanguageOption extends StatelessWidget {
  const LanguageOption({
    super.key,
    required this.language,
  });

  final Language language;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: context.watch<LanguageSettingsCubit>().state == language,
      title: Text(
        '${language.languageCode}${language.countryCode != null ? ' (${language.countryCode})' : ''}',
      ),
      onTap: () {
        context.read<LanguageSettingsCubit>().changeLanguage(language);
      },
    );
  }
}
