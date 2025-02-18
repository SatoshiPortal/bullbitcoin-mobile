import 'package:bb_mobile/build_context_x.dart';
import 'package:bb_mobile/features/language/domain/entities/language.dart';
import 'package:bb_mobile/features/language/presentation/bloc/language_settings_cubit.dart';
import 'package:bb_mobile/features/language/presentation/widgets/language_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<LanguageSettingsCubit, Language?>(
      listener: (context, state) => GoRouter.of(context).pop(),
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
