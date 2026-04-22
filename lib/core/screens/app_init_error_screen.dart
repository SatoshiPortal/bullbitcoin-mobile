import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
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
  Locale _locale = const Locale('en');

  String _localeName(Locale locale) {
    final match = Language.values.where(
      (l) =>
          l.languageCode == locale.languageCode &&
          (locale.countryCode == null || l.countryCode == locale.countryCode),
    );
    return match.isNotEmpty
        ? match.first.label
        : locale.languageCode.toUpperCase();
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share logs: $e')),
      );
    }
  }

  Future<void> _contactSupport() async {
    await launchUrl(
      Uri.parse(SettingsConstants.webSupportLink),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = lookupAppLocalizations(_locale);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData(AppThemeType.dark),
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
                        _buildLocalePicker(context),
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
                    Row(
                      children: [
                        Expanded(
                          child: BBButton.big(
                            label: loc.appInitErrorContactSupportButton,
                            iconData: Icons.open_in_new,
                            bgColor: context.appColors.primary,
                            textColor: context.appColors.onPrimary,
                            onPressed: _contactSupport,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BBButton.big(
                            label: loc.appInitErrorShareLogsButton,
                            iconData: Icons.share,
                            iconFirst: true,
                            bgColor: context.appColors.surface,
                            textColor: context.appColors.text,
                            borderColor: context.appColors.border,
                            outlined: true,
                            onPressed: () => _shareLogs(context),
                          ),
                        ),
                      ],
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

  Widget _buildLocalePicker(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<Locale>(
      onSelected: (locale) => setState(() => _locale = locale),
      constraints: const BoxConstraints(maxHeight: 300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      itemBuilder: (context) => AppLocalizations.supportedLocales.map((locale) {
        return PopupMenuItem<Locale>(
          value: locale,
          child: Text(
            _localeName(locale),
            style: theme.textTheme.bodyMedium,
          ),
        );
      }).toList(),
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
              Icon(Icons.language, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 120),
                child: Text(
                  _localeName(_locale),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
            ],
          ),
        ),
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

class _ErrorDetails extends StatelessWidget {
  const _ErrorDetails({required this.error, required this.label});

  final Object error;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      // Strip ExpansionTile's default divider + padding.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        iconColor: theme.colorScheme.onSurface,
        collapsedIconColor: theme.colorScheme.onSurface,
        title: Text(label, style: theme.textTheme.bodyMedium),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.surfaceContainer,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: context.appColors.border),
            ),
            child: SelectableText(
              error.toString(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
