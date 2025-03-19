import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_utils/build_context_x.dart';
import 'package:bb_mobile/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/settings/ui/widgets/language_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsCubit, SettingsState?>(
      listenWhen: (previous, current) =>
          current?.language != previous?.language,
      listener: (context, state) => context.pop(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.loc.languageSettingsScreenTitle),
        ),
        body: SafeArea(
          child: ListView(
            children: Language.values
                .map(
                  (language) => LanguageOption(
                    language: language,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
