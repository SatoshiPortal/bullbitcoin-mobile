import 'dart:ui' show PlatformDispatcher;

import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullScaffold,
        BullSupportButton,
        BullText,
        BullTextRole,
        BullThemeX,
        Gap;
import 'package:material_ui/material_ui.dart';
import 'package:preferences/preferences.dart' show Language;
import 'package:startup/generated/l10n/startup_localizations.dart';

/// Blocks startup when the wallet storage cannot be read.
///
/// Offers no action that touches the data: retry, support and quit only.
class InventoryUnreadableScreen extends StatefulWidget {
  const InventoryUnreadableScreen({
    super.key,
    required this.onRetry,
    required this.onQuit,
    this.extraLocalizations = const [],
  });

  final VoidCallback onRetry;
  final VoidCallback onQuit;
  final List<LocalizationsDelegate<dynamic>> extraLocalizations;

  @override
  State<InventoryUnreadableScreen> createState() =>
      _InventoryUnreadableScreenState();
}

class _InventoryUnreadableScreenState extends State<InventoryUnreadableScreen> {
  bool _retrying = false;

  @override
  void didUpdateWidget(covariant InventoryUnreadableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onRetry != widget.onRetry) _retrying = false;
  }

  // The caller completes a one-shot future: a second call would throw.
  void _retry() {
    if (_retrying) return;
    setState(() => _retrying = true);
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    final platform = PlatformDispatcher.instance.locale;
    final language = Language.fromLocaleTags(
      languageCode: platform.languageCode,
      countryCode: platform.countryCode,
      scriptCode: platform.scriptCode,
    );
    final locale = Locale.fromSubtags(
      languageCode: language.languageCode,
      scriptCode: language.scriptCode,
      countryCode: language.countryCode,
    );
    final loc = lookupStartupLocalizations(locale);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData(AppThemeType.dark),
      locale: locale,
      localizationsDelegates: [
        StartupLocalizations.delegate,
        ...widget.extraLocalizations,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: StartupLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => BullScaffold(
          backgroundColor: context.bull.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: BullText(
                      loc.inventoryUnreadableTitle,
                      role: BullTextRole.subtitle,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Gap(16),
                  BullText(
                    loc.inventoryUnreadableMessage,
                    role: BullTextRole.body,
                  ),
                  const Gap(24),
                  BullButton.primary(
                    label: loc.retry,
                    onPressed: _retrying ? null : _retry,
                  ),
                  const Gap(12),
                  BullSupportButton.big(
                    label: loc.appInitErrorContactSupportButton,
                    icon: Icons.open_in_new,
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
                  const Gap(12),
                  BullButton.secondary(
                    label: loc.inventoryUnreadableQuitButton,
                    onPressed: widget.onQuit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
