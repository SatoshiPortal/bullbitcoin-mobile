import 'package:bb_mobile/features/settings/public/settings_facade.dart'
    show Language, LanguageExtension;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/widgets/translation_warning_bottom_sheet.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullLanguagePicker,
        BullPickerItem,
        BullScaffold,
        BullShapesX,
        BullSnackBar,
        BullSupportButton,
        BullText,
        BullTextRole,
        BullThemeX,
        BullTypographyX,
        Gap;

class AppInitErrorScreen extends StatefulWidget {
  const AppInitErrorScreen({super.key, required this.error});

  final Object error;

  @override
  State<AppInitErrorScreen> createState() => _AppInitErrorScreenState();
}

class _AppInitErrorScreenState extends State<AppInitErrorScreen> {
  Language _language = Language.fromKeyboard();

  Future<void> _shareLogs(BuildContext context, AppLocalizations loc) async {
    try {
      final logs = await readLogsForSharing();
      await shareLogsAsFile(logs);
    } catch (e) {
      log.severe(
        message: 'Failed to share logs',
        error: e,
        trace: StackTrace.current,
      );
      if (!context.mounted) return;
      BullSnackBar.show(
        context,
        message: loc.errorSharingLogsMessage(e.toString()),
      );
    }
  }

  Future<void> _exportLogs(BuildContext context, AppLocalizations loc) async {
    try {
      final logs = await readLogsForSharing();
      final saved = await exportLogsAsFile(logs);
      if (!context.mounted) return;
      if (saved) {
        BullSnackBar.show(context, message: loc.logsExportedMessage);
      }
    } catch (e) {
      log.severe(
        message: 'Failed to export logs',
        error: e,
        trace: StackTrace.current,
      );
      if (!context.mounted) return;
      BullSnackBar.show(context, message: loc.logsExportFailedMessage);
    }
  }

  Future<void> _deleteLogs(BuildContext context, AppLocalizations loc) async {
    await log.deleteLogs();
    if (!context.mounted) return;
    BullSnackBar.show(context, message: loc.logsDeletedMessage);
  }

  @override
  Widget build(BuildContext context) {
    final loc = lookupAppLocalizations(_language.locale);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData(AppThemeType.dark),
      locale: _language.locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          // Seed Device.screen so TranslationWarningBottomSheet
          // (which read it synchronously) work on this pre-init screen.
          Device.init(context);
          return BullScaffold(
            backgroundColor: context.bull.background,
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
                          child: Semantics(
                            header: true,
                            child: BullText(
                              loc.appInitErrorTitle,
                              role: BullTextRole.subtitle,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        BullLanguagePicker<Language>(
                          value: _language,
                          languages: [
                            for (final language in Language.values)
                              BullPickerItem(
                                value: language,
                                label: language.label,
                              ),
                          ],
                          onChanged: (lang) {
                            setState(() => _language = lang);
                            if (lang.isMachineTranslated) {
                              TranslationWarningBottomSheet.show(context);
                            }
                          },
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
                    BullSupportButton.big(
                      label: loc.appInitErrorContactSupportButton,
                      icon: Icons.open_in_new,
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                    ),
                    const Gap(12),
                    BullButton.secondary(
                      label: loc.appInitErrorShareLogsButton,
                      iconData: Icons.share,
                      iconFirst: true,
                      onPressed: () => _shareLogs(context, loc),
                    ),
                    const Gap(12),
                    BullButton.secondary(
                      label: loc.logsShareOptionExport,
                      iconData: Icons.file_download_outlined,
                      iconFirst: true,
                      onPressed: () => _exportLogs(context, loc),
                    ),
                    const Gap(12),
                    BullButton.secondary(
                      label: loc.deleteLogsTitle,
                      iconData: Icons.delete_outline,
                      iconFirst: true,
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
        Semantics(
          header: true,
          child: BullText(
            title,
            role: BullTextRole.title,
            fontWeight: FontWeight.bold,
            textAlign: TextAlign.center,
          ),
        ),
        const Gap(8),
        BullText(message, role: BullTextRole.body, textAlign: TextAlign.center),
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
    return Column(
      children: [
        Semantics(
          expanded: _expanded,
          child: BullButton.secondary(
            label: widget.label,
            iconData: _expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            iconFirst: true,
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.surfaceContainer,
              borderRadius: BorderRadius.circular(context.bullShapes.card),
              border: Border.all(color: context.appColors.border),
            ),
            child: SelectableText(
              widget.error.toString(),
              style: context.bullType.caption.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ],
    );
  }
}
