import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart' show Device;
import 'package:bb_mobile/core/widgets/app_language_picker.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Chrome for the screens that run *before* `Bull.init` has produced a
/// locator, a router or a settings repository.
///
/// Those screens can't use the app shell — there is no `SettingsCubit`
/// to read a language from and no `GoRouter` to sit inside — so each one
/// has to raise its own [MaterialApp] and pick a locale from the
/// keyboard. This is that boilerplate, in one place, so a new failure
/// screen is a list of widgets rather than another copy of the shell.
class PreInitScaffold extends StatefulWidget {
  /// Optional heading rendered on the same row as the language picker.
  final String Function(AppLocalizations loc)? title;

  /// Body of the screen. Receives the localizations for the currently
  /// picked language so callers never reach for `context.loc`, which
  /// isn't wired up this early.
  final List<Widget> Function(BuildContext context, AppLocalizations loc)
  builder;

  const PreInitScaffold({super.key, this.title, required this.builder});

  @override
  State<PreInitScaffold> createState() => _PreInitScaffoldState();
}

class _PreInitScaffoldState extends State<PreInitScaffold> {
  Language _language = Language.fromKeyboard();

  @override
  Widget build(BuildContext context) {
    final loc = lookupAppLocalizations(_language.locale);
    final title = widget.title?.call(loc);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData(AppThemeType.dark),
      locale: _language.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          // Seed Device.screen so AppLanguagePicker /
          // TranslationWarningBottomSheet (which read it synchronously)
          // work on this pre-init screen.
          Device.init(context);
          return Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: title == null
                              ? const SizedBox.shrink()
                              : Text(
                                  title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                        ),
                        const SizedBox(width: 12),
                        AppLanguagePicker(
                          value: _language,
                          onChanged: (lang) => setState(() => _language = lang),
                        ),
                      ],
                    ),
                    const Gap(24),
                    ...widget.builder(context, loc),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Illustration + heading + body copy, the block every pre-init screen
/// leads with.
class PreInitIllustration extends StatelessWidget {
  final String asset;
  final String title;
  final String message;

  const PreInitIllustration({
    super.key,
    required this.asset,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SvgPicture.asset(
            asset,
            height: 120,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => const SizedBox(height: 120),
          ),
        ),
        const Gap(16),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(8),
        Text(
          message,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
