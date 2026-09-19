import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/status_check/public/service_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsGroupScreen extends StatelessWidget {
  final bool _help;
  const SettingsGroupScreen.tools({super.key}) : _help = false;
  const SettingsGroupScreen.help({super.key}) : _help = true;

  @override
  Widget build(BuildContext context) {
    final items = settingsItemsOf(context);
    final Color? statusColor;
    if (_help) {
      final state = context.watch<ServiceStatusCubit>().state;
      statusColor = state.isLoading
          ? context.appColors.textMuted
          : state.serviceStatus.allServicesOnline
          ? context.appColors.success
          : context.appColors.error;
    } else {
      statusColor = null;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _help
              ? context.loc.settingsHelpAndInfoTitle
              : context.loc.settingsToolsTitle,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final item in items.inSection(
              _help ? SettingsItemSection.help : SettingsItemSection.tools,
            ))
              item.buildTile(
                context,
                iconColor: item.id == SettingsItemId.servicesStatus
                    ? statusColor
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
