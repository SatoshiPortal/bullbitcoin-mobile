import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/settings_route.dart';
import 'package:bb_mobile/features/settings/ui/widgets/settings_search_bar.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:bull_ui/bull_ui.dart' show BullScrollableColumn, Gap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class AllSettingsScreen extends StatefulWidget {
  const AllSettingsScreen({super.key});

  @override
  State<AllSettingsScreen> createState() => _AllSettingsScreenState();
}

class _AllSettingsScreenState extends State<AllSettingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ServiceStatusCubit>().checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final appVersion = context.select(
      (SettingsCubit cubit) => cubit.state.appVersion,
    );

    final serviceStatusLoading = context.select(
      (ServiceStatusCubit cubit) => cubit.state.isLoading,
    );

    final serviceStatus = context.select(
      (ServiceStatusCubit cubit) => cubit.state.serviceStatus,
    );

    final items = settingsItemsOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsScreenTitle)),
      body: SafeArea(
        child: BullScrollableColumn(
          padding: EdgeInsets.zero,
          mainAxisAlignment: .spaceBetween,
          children: [
            Padding(
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
                          ? serviceStatusLoading
                                ? context.appColors.textMuted
                                : serviceStatus.allServicesOnline
                                ? context.appColors.success
                                : context.appColors.error
                          : null,
                    ),
                ],
              ),
            ),
            Material(
              color: context.appColors.transparent,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .stretch,
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
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Wrap(
                        alignment: .spaceEvenly,
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          InkWell(
                            onTap: () =>
                                items.byId(SettingsItemId.github).open(context),
                            child: Column(
                              mainAxisSize: .min,
                              children: [
                                SvgPicture.asset(
                                  'assets/icons/github.svg',
                                  width: 24,
                                  height: 24,
                                  colorFilter: ColorFilter.mode(
                                    context.appColors.onSurface,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                const Gap(8),
                                Text(
                                  context.loc.settingsGithubLabel,
                                  textAlign: .center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: context.appColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => items
                                .byId(SettingsItemId.supportChat)
                                .open(context),
                            child: Column(
                              mainAxisSize: .min,
                              children: [
                                Icon(
                                  Icons.headset_mic,
                                  color: context.appColors.onSurface,
                                ),
                                const Gap(8),
                                Text(
                                  context.loc.settingsGetHelpLabel,
                                  textAlign: .center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: context.appColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
