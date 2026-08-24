import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/widgets/settings_search_sheet.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _openSettingsSearch(List<SettingsItem> items) async {
    final item = await SettingsSearchSheet.show(context: context, items: items);
    if (item == null || !mounted) return;
    item.open(context);
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
      appBar: AppBar(
        title: Text(context.loc.settingsScreenTitle),
        actionsPadding: const EdgeInsets.only(right: 8),
        actions: [
          IconButton(
            key: const Key('settings-search-button'),
            tooltip: context.loc.settingsSearchHint,
            color: context.appColors.secondary,
            iconSize: 32,
            icon: const Icon(Icons.search),
            onPressed: () => _openSettingsSearch(items),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const Gap(16),
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
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 150,
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
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Row(
                  mainAxisAlignment: .spaceEvenly,
                  children: [
                    InkWell(
                      onTap: () {
                        final url = Uri.parse(
                          SettingsConstants.githubSupportLink,
                        );
                        launchUrl(url, mode: LaunchMode.externalApplication);
                      },
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: context.appColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        final notLoggedIn = context
                            .read<ExchangeCubit>()
                            .state
                            .notLoggedIn;
                        if (notLoggedIn) {
                          context.goNamed(
                            ExchangeRoute.exchangeLoginForSupport.name,
                          );
                        } else {
                          context.goNamed(ExchangeSupportChatFacade.routeName);
                        }
                      },
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
    );
  }
}
