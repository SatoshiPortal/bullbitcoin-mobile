import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppInitErrorScreen extends StatefulWidget {
  const AppInitErrorScreen({
    super.key,
    required this.error,
  });

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

  @override
  Widget build(BuildContext context) {
    // Look up translations directly — avoids MaterialApp locale async resolution
    final loc = lookupAppLocalizations(_locale);
    return MaterialApp(
      theme: AppTheme.themeData(AppThemeType.dark),
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: PopupMenuButton<Locale>(
                        onSelected: (locale) =>
                            setState(() => _locale = locale),
                        constraints: const BoxConstraints(maxHeight: 300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                        itemBuilder: (context) =>
                            AppLocalizations.supportedLocales.map((locale) {
                              final name = _localeName(locale);
                              return PopupMenuItem<Locale>(
                                value: locale,
                                child: Text(
                                  name,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              );
                            }).toList(),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.language,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minWidth: 120),
                                child: Text(
                                  _localeName(_locale),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.appInitErrorTitle,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      loc.appInitErrorMessage,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => launchUrl(
                        Uri.parse(SettingsConstants.webSupportLink),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        SettingsConstants.webSupportLink.replaceFirst(
                          'https://',
                          '',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border.all(
                              color: theme.colorScheme.error,
                            ),
                          ),
                          child: SelectableText(
                            widget.error.toString(),
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _shareLogs(context),
                        icon: const Icon(Icons.share),
                        label: Text(loc.appInitErrorShareLogsButton),
                      ),
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
