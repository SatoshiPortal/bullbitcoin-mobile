import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HelpSettingsScreen extends StatelessWidget {
  const HelpSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = settingsItemsOf(context);
    final isLoading = context.select(
      (ServiceStatusCubit cubit) => cubit.state.isLoading,
    );
    final serviceStatus = context.select(
      (ServiceStatusCubit cubit) => cubit.state.serviceStatus,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsHelpAndInfoTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final item in items.inSection(SettingsItemSection.help))
                  item.buildTile(
                    context,
                    iconColor: item.id == SettingsItemId.servicesStatus
                        ? isLoading
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
    );
  }
}
