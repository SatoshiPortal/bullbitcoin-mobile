import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/settings_route.dart';
import 'package:bb_mobile/features/settings/ui/widgets/settings_search_bar.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_settings_service_health_usecase.dart';
import 'package:bull_ui/bull_ui.dart' show Gap, BullTypographyX;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AllSettingsScreen extends StatefulWidget {
  final Stream<SettingsServiceHealth> Function() watchServiceHealth;

  const AllSettingsScreen({required this.watchServiceHealth, super.key});

  @override
  State<AllSettingsScreen> createState() => _AllSettingsScreenState();
}

class _AllSettingsScreenState extends State<AllSettingsScreen> {
  late final _serviceHealth = widget.watchServiceHealth();

  @override
  Widget build(BuildContext context) => StreamBuilder<SettingsServiceHealth>(
    stream: _serviceHealth,
    builder: (context, snapshot) => ExchangeAccessBuilder(
      builder: (context, access) => _build(context, access, snapshot.data),
    ),
  );

  Widget _build(
    BuildContext context,
    ExchangeAccess access,
    SettingsServiceHealth? serviceHealth,
  ) {
    final appVersion = context.select(
      (SettingsCubit cubit) => cubit.state.appVersion,
    );

    final ready = ExchangeAvailability.canManageAccount(access);
    final items = settingsItemsOf(context, accountReady: ready);

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsScreenTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const Gap(16),
                SettingsSearchBar(
                  key: const Key('settings-search-bar'),
                  onTap: () => context.pushNamed(SettingsRoute.search.name),
                ),
                const Gap(8),
                for (final item in items.inSection(SettingsItemSection.root))
                  item.buildTile(
                    context,
                    iconColor: item.id == SettingsItemId.servicesStatus
                        ? switch (serviceHealth) {
                            null || SettingsServiceHealth.checking =>
                              context.appColors.textMuted,
                            SettingsServiceHealth.healthy =>
                              context.appColors.success,
                            SettingsServiceHealth.unhealthy =>
                              context.appColors.error,
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
        color: context.appColors.transparent,
        child: SafeArea(
          child: Column(
            mainAxisSize: .min,
            children: [
              if (appVersion != null)
                ListTile(
                  tileColor: context.appColors.surfaceContainerHighest,
                  title: Center(
                    child: Text(
                      '${context.loc.settingsAppVersionLabel}$appVersion',
                      style: context.bullType.caption.copyWith(
                        color: context.appColors.onSurface,
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
