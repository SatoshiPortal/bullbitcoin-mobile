import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LanguageOption extends StatelessWidget {
  const LanguageOption({super.key, required this.language});

  final Language language;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      tileColor: context.appColors.transparent,
      selected: context.watch<SettingsCubit>().state.language == language,
      title: Text(
        '${language.languageCode}${language.countryCode != null ? ' (${language.countryCode})' : ''}',
      ),
      onTap: () {
        context.read<SettingsCubit>().changeLanguage(language);
      },
    );
  }
}
