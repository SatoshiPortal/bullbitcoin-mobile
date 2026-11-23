import 'package:background_tasks/background_tasks.dart'
    show
        SharedPreferencesBackgroundSyncIntervalRepository,
        backgroundSyncAvailable;
import 'package:notifications/notifications.dart'
    show NotificationPermissionsFacade, notificationPermissions;
import 'package:preferences/preferences.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:wizard/src/data/datasource/wizard_local_datasource.dart';
import 'package:wizard/src/data/repository/wizard_repository_impl.dart';
import 'package:wizard/src/domain/entity/wizard_choices.dart';
import 'package:wizard/src/ui/wizard_branding.dart';
import 'package:wizard/src/domain/usecase/mark_wizard_complete_usecase.dart';
import 'package:wizard/src/domain/usecase/notification_permission_usecase.dart';
import 'package:wizard/src/domain/usecase/read_background_tasks_usecase.dart';
import 'package:wizard/src/domain/usecase/save_pending_wizard_choices_usecase.dart';
import 'package:wizard/src/presentation/bloc/wizard_bloc.dart';
import 'package:wizard/src/ui/screens/wizard_screen.dart';
import 'package:wizard/generated/l10n/wizard_localizations.dart';
import 'package:wizard/generated/novlang/novlang_wizard_localizations.dart';
import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:novlang/novlang.dart';
import 'package:settings/settings.dart' show SettingsLocalizations;

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
  const WizardApp({
    super.key,
    required this.onDone,
    required this.notificationChannelId,
    required this.exchangeAllowed,
    required this.branding,
  });

  final ValueChanged<WizardChoices> onDone;
  final String notificationChannelId;
  final bool exchangeAllowed;
  final WizardBranding branding;

  WizardBloc _createBloc() {
    final datasource = WizardLocalDatasourceImpl();
    final repository = WizardRepositoryImpl(datasource);
    return WizardBloc(
      savePending: SavePendingWizardChoicesUsecase(repository: repository),
      markComplete: MarkWizardCompleteUsecase(repository: repository),
      readBackgroundTasks: ReadBackgroundTasksUsecase(
        intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
      ),
      notificationPermission: NotificationPermissionUsecase(
        permissions: NotificationPermissionsFacade(
          gateway: notificationPermissions(channelId: notificationChannelId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WizardBloc>(
      create: (_) {
        final bloc = _createBloc();
        // Without background tasks there is nothing to read nor to offer.
        if (backgroundSyncAvailable) bloc.add(const WizardEvent.started());
        return bloc;
      },
      child: _WizardAppView(
        onDone: onDone,
        exchangeAllowed: exchangeAllowed,
        branding: branding,
      ),
    );
  }
}

class _WizardAppView extends StatelessWidget {
  const _WizardAppView({
    required this.onDone,
    required this.exchangeAllowed,
    required this.branding,
  });

  final ValueChanged<WizardChoices> onDone;
  final bool exchangeAllowed;
  final WizardBranding branding;

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
          locale: Locale.fromSubtags(
            languageCode: state.choices.language.languageCode,
            scriptCode: state.choices.language.scriptCode,
            countryCode: state.choices.language.countryCode,
          ),
          // The wizard runs before the main app and its settings exist: the
          // store constraint of the platform applies (superuser unknown).
          localizationsDelegates: [
            NovlangWizardLocalizationsDelegate(
              resolveNovlangPolicy(defaultTargetPlatform, null),
            ),
            ExchangeLocalizations.delegate,
            SettingsLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: WizardLocalizations.supportedLocales,
          home: WizardScreen(
            backgroundTasksAvailable: backgroundSyncAvailable,
            exchangeAllowed: exchangeAllowed,
            branding: branding,
          ),
        );
      },
    );
  }
}
