import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/settings_route.dart';
import 'package:bb_mobile/features/settings/ui/widgets/settings_search_bar.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AllSettingsScreen extends StatelessWidget {
  const AllSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final appVersion = context.select(
      (SettingsCubit cubit) => cubit.state.appVersion,
    );

    final items = settingsItemsOf(context);

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
                  item.buildTile(context),
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
                      style: theme.textTheme.labelMedium?.copyWith(
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
