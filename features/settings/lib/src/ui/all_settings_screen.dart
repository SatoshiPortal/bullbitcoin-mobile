import 'package:bull_ui/bull_ui.dart'
    show BullSearchBar, BullSettingsEntryItem, BullThemeX, Gap, BullTypographyX;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../domain/watch_settings_service_health_usecase.dart';
import '../settings_menu.dart';

class AllSettingsScreen extends StatefulWidget {
  final Stream<SettingsServiceHealth> Function() watchServiceHealth;
  final SettingsMenu Function(BuildContext) menuOf;
  final SettingsLabels Function(BuildContext) labelsOf;
  final void Function(BuildContext) openSearch;

  const AllSettingsScreen({
    required this.watchServiceHealth,
    required this.menuOf,
    required this.labelsOf,
    required this.openSearch,
  });

  @override
  State<AllSettingsScreen> createState() => _AllSettingsScreenState();
}

class _AllSettingsScreenState extends State<AllSettingsScreen> {
  late final _serviceHealth = widget.watchServiceHealth();

  @override
  Widget build(BuildContext context) => StreamBuilder<SettingsServiceHealth>(
    stream: _serviceHealth,
    builder: (context, snapshot) => _build(context, snapshot.data),
  );

  Widget _build(BuildContext context, SettingsServiceHealth? serviceHealth) {
    final menu = widget.menuOf(context);
    final labels = widget.labelsOf(context);
    final appVersion = menu.appVersion;

    return Scaffold(
      appBar: AppBar(title: Text(labels.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const Gap(16),
                BullSearchBar.button(
                  key: const Key('settings-search-bar'),
                  label: labels.searchHint,
                  onTap: () => widget.openSearch(context),
                ),
                const Gap(8),
                for (final item in menu.entries.where(
                  (item) => item.showOnHome,
                ))
                  BullSettingsEntryItem(
                    icon: item.icon,
                    leading: item.homeIcon,
                    title: item.title,
                    isSuperUser: item.isSuperuser,
                    onTap: () => item.open(context),
                    iconColor: item.indicatesServiceHealth
                        ? switch (serviceHealth) {
                            null || SettingsServiceHealth.checking =>
                              context.bull.textMuted,
                            SettingsServiceHealth.healthy =>
                              context.bull.success,
                            SettingsServiceHealth.unhealthy =>
                              context.bull.error,
                          }
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 72,
        padding: EdgeInsets.zero,
        color: context.bull.transparent,
        child: SafeArea(
          child: Column(
            mainAxisSize: .min,
            children: [
              if (appVersion != null)
                ListTile(
                  tileColor: context.bull.surfaceContainerHighest,
                  title: Center(
                    child: Text(
                      '${labels.appVersionLabel}$appVersion',
                      style: context.bullType.caption.copyWith(
                        color: context.bull.onSurface,
                      ),
                    ),
                  ),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: appVersion));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
