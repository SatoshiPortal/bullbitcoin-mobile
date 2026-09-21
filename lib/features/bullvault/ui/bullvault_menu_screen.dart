import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_settings_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_card.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

final class BullVaultMenuScreen extends StatefulWidget {
  final String registerExternalRouteName;
  const BullVaultMenuScreen({
    super.key,
    required this.registerExternalRouteName,
  });
  @override
  State<BullVaultMenuScreen> createState() => _BullVaultMenuScreenState();
}

final class _BullVaultMenuScreenState extends State<BullVaultMenuScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<BullVaultSettingsCubit>().load();
    }
  }

  Future<void> _open(
    String route, {
    String? walletId,
    Map<String, String> query = const {},
  }) async {
    await context.pushNamed(
      route,
      pathParameters: walletId == null ? const {} : {'walletId': walletId},
      queryParameters: query,
    );
    if (mounted) await context.read<BullVaultSettingsCubit>().load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.bullVaultMenuTitle)),
    body: SafeArea(
      child: BlocBuilder<BullVaultSettingsCubit, BullVaultSettingsState>(
        builder: (context, state) => switch (state) {
          BullVaultSettingsLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          BullVaultMenuLoaded(:final records) => _content(records),
          BullVaultSettingsFailed() ||
          BullVaultInspectionLoaded() => _content(const [], failed: true),
        },
      ),
    ),
  );
  Widget _content(List<BullVaultRecord> records, {bool failed = false}) =>
      ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (failed) ...[
            Text(context.loc.walletDetailsUnavailableLabel),
            TextButton(
              onPressed: () => context.read<BullVaultSettingsCubit>().load(),
              child: Text(context.loc.retry),
            ),
          ],
          for (final record in records) ...[
            BullVaultCard(
              record: record,
              onTap: () => _open(
                BullVaultFacade.settingsRouteName,
                walletId: record.walletId,
              ),
            ),
            const Gap(16),
          ],
          SettingsEntryItem(
            icon: Icons.add,
            title: context.loc.bullVaultCreateEntry,
            onTap: () => _open(BullVaultFacade.createRouteName),
          ),
          SettingsEntryItem(
            icon: Icons.restore_page_outlined,
            title: context.loc.bullVaultRecoverEntry,
            onTap: () => _open(BullVaultFacade.restoreRouteName),
          ),
          SettingsEntryItem(
            icon: Icons.key_outlined,
            title: context.loc.bullVaultUseBullAsSigner,
            onTap: () => _open(SettingsRoute.signingKeyExport.name),
          ),
          SettingsEntryItem(
            icon: Icons.playlist_add,
            title: context.loc.bullVaultRegisterExternalEntry,
            onTap: () => _open(widget.registerExternalRouteName),
          ),
          SettingsEntryItem(
            icon: Icons.science_outlined,
            title: context.loc.bullVaultCreatePracticeEntry,
            subtitle: context.loc.bullVaultPracticeTimelineDescription,
            onTap: () => _open(
              BullVaultFacade.createRouteName,
              query: const {'practice': 'true'},
            ),
          ),
        ],
      );
}
