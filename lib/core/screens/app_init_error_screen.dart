import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/app_language_picker.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppInitErrorScreen extends StatefulWidget {
  const AppInitErrorScreen({super.key, required this.error});

  final Object error;

  @override
  State<AppInitErrorScreen> createState() => _AppInitErrorScreenState();
}

class _AppInitErrorScreenState extends State<AppInitErrorScreen> {
  Language _language = Language.unitedStatesEnglish;

  Future<void> _shareLogs(BuildContext context) async {
    try {
      final logs = await log.readLogs();
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          text: logs.join('\n'),
          subject: 'bull_logs.tsv',
          title: 'bull_logs.tsv',
        ),
      );
    } catch (e) {
      log.severe(
        message: 'Failed to share logs',
        error: e,
        trace: StackTrace.current,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to share logs: $e')));
    }
  }

  Future<void> _contactSupport() async {
    await launchUrl(
      Uri.parse(SettingsConstants.webSupportLink),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _deleteLogs(BuildContext context, AppLocalizations loc) async {
    await log.deleteLogs();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.logsDeletedMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = lookupAppLocalizations(_language.locale);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData(AppThemeType.dark),
      locale: _language.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
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
                          child: Text(
                            loc.appInitErrorTitle,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        AppLanguagePicker(
                          value: _language,
                          onChanged: (lang) =>
                              setState(() => _language = lang),
                        ),
                      ],
                    ),
                    const Gap(24),
                    _BackupSection(
                      asset: 'assets/misc/undraw_secure-usb-drive.svg',
                      title: loc.appInitErrorHasBackupTitle,
                      message: loc.appInitErrorHasBackupMessage,
                    ),
                    const Gap(32),
                    Divider(color: context.appColors.border),
                    const Gap(32),
                    _BackupSection(
                      asset: 'assets/misc/undraw_forgot-password.svg',
                      title: loc.appInitErrorNoBackupTitle,
                      message: loc.appInitErrorNoBackupMessage,
                    ),
                    const Gap(32),
                    BBButton.big(
                      label: loc.appInitErrorContactSupportButton,
                      iconData: Icons.open_in_new,
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                      onPressed: _contactSupport,
                    ),
                    const Gap(12),
                    BBButton.big(
                      label: loc.appInitErrorShareLogsButton,
                      iconData: Icons.share,
                      iconFirst: true,
                      bgColor: context.appColors.surface,
                      textColor: context.appColors.text,
                      borderColor: context.appColors.border,
                      outlined: true,
                      onPressed: () => _shareLogs(context),
                    ),
                    const Gap(12),
                    BBButton.big(
                      label: loc.deleteLogsTitle,
                      iconData: Icons.delete_outline,
                      iconFirst: true,
                      bgColor: context.appColors.surface,
                      textColor: context.appColors.error,
                      borderColor: context.appColors.error,
                      outlined: true,
                      onPressed: () => _deleteLogs(context, loc),
                    ),
                    const Gap(16),
                    _ErrorDetails(
                      error: widget.error,
                      label: loc.appInitErrorDetailsToggle,
                    ),
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

class _BackupSection extends StatelessWidget {
  const _BackupSection({
    required this.asset,
    required this.title,
    required this.message,
  });

  final String asset;
  final String title;
  final String message;

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

class _ErrorDetails extends StatefulWidget {
  const _ErrorDetails({required this.error, required this.label});

  final Object error;
  final String label;

  @override
  State<_ErrorDetails> createState() => _ErrorDetailsState();
}

class _ErrorDetailsState extends State<_ErrorDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bug_report_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.surfaceContainer,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: context.appColors.border),
            ),
            child: SelectableText(
              widget.error.toString(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}
