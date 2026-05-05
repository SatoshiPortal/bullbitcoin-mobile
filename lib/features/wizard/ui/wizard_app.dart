import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/data/repository/wizard_repository_impl.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/mark_wizard_complete_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/save_pending_wizard_choices_usecase.dart';
import 'package:bb_mobile/features/wizard/presentation/bloc/wizard_bloc.dart';
import 'package:bb_mobile/features/wizard/ui/screens/wizard_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Standalone app shown before `Bull.init` runs to every user whose
/// stored wizard version is below `kCurrentWizardVersion`. Intentionally
/// has no dependency on the locator, FRB bridges or other feature bloc
/// providers — anything needed later must not be required to render
/// this wizard. Wires the [WizardBloc] manually (datasource → repo →
/// usecases → bloc) since the `GetIt` locator isn't yet up at this
/// point in `main()`.
///
/// Back-gesture handling lives inside [WizardScreen] — it steps the
/// PageView back one page on each pop and blocks the actual app pop
/// while on page 1 (so consent collection can't be skipped before
/// migrations / Sentry init run).
class WizardApp extends StatelessWidget {
  const WizardApp({super.key, required this.onDone});

  final ValueChanged<WizardChoices> onDone;

  WizardBloc _createBloc() {
    final datasource = WizardLocalDatasourceImpl();
    final repository = WizardRepositoryImpl(datasource);
    return WizardBloc(
      savePending: SavePendingWizardChoicesUsecase(repository: repository),
      markComplete: MarkWizardCompleteUsecase(repository: repository),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WizardBloc>(
      create: (_) => _createBloc(),
      child: _WizardAppView(onDone: onDone),
    );
  }
}

class _WizardAppView extends StatelessWidget {
  const _WizardAppView({required this.onDone});

  final ValueChanged<WizardChoices> onDone;

  @override
  Widget build(BuildContext context) {
    Device.init(context);
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    return BlocConsumer<WizardBloc, WizardState>(
      listenWhen: (a, b) => !a.finished && b.finished,
      listener: (context, state) => onDone(state.choices),
      buildWhen: (a, b) =>
          a.choices.themeMode != b.choices.themeMode ||
          a.choices.language != b.choices.language,
      builder: (context, state) {
        final appThemeType = switch (state.choices.themeMode) {
          AppThemeMode.light => AppThemeType.light,
          AppThemeMode.dark => AppThemeType.dark,
          AppThemeMode.system =>
            systemBrightness == Brightness.dark
                ? AppThemeType.dark
                : AppThemeType.light,
        };
        return MaterialApp(
          title: 'Bull',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeData(appThemeType),
          locale: state.choices.language.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WizardScreen(),
        );
      },
    );
  }
}
