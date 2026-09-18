import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/warning_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/backup_identity_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/keychain_manifest_failure_l10n.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/nostr_keys_cubit.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/screens/nostr_key_detail_screen.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/screens/nostr_key_form_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, Gap, BullSpacing;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NostrKeysScreen extends StatelessWidget {
  const NostrKeysScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => locator<NostrKeysCubit>()..load(),
    child: const _NostrKeysView(),
  );
}

class _NostrKeysView extends StatelessWidget {
  const _NostrKeysView();

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<NostrKeysCubit, NostrKeysState>(
    builder: (context, state) => Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsNostrKeysTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(BullSpacing.lg),
          children: [
            if (state.loading) const Center(child: CircularProgressIndicator()),
            if (state.failure != null) ...[
              Text(
                state.failure!.toTranslated(context),
                style: TextStyle(color: context.appColors.error),
              ),
              TextButton(
                onPressed: context.read<NostrKeysCubit>().load,
                child: Text(context.loc.retry),
              ),
            ],
            if (!state.loading && state.keys.isEmpty && state.failure == null)
              Text(context.loc.settingsNostrKeysEmpty),
            for (final record in state.keys)
              ListTile(
                title: Text(record.purpose),
                subtitle: record.description.isEmpty
                    ? null
                    : Text(record.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => NostrKeyDetailScreen.user(record),
                  ),
                ),
              ),
            const Gap(BullSpacing.lg),
            BullButton.big(
              key: const ValueKey('create-nostr-key'),
              label: context.loc.settingsNostrKeysCreate,
              onPressed: () => _create(context),
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
            ),
            const Gap(BullSpacing.lg),
            TextButton(
              key: const ValueKey('show-system-keys'),
              onPressed: () => _toggleSystemKeys(context, state),
              child: Text(
                state.systemKeys != null || state.loadingSystem
                    ? context.loc.settingsNostrKeysHideSystemKeys
                    : context.loc.settingsNostrKeysShowSystemKeys,
              ),
            ),
            if (state.loadingSystem)
              const Center(child: CircularProgressIndicator()),
            for (final record
                in state.systemKeys ?? const <BackupIdentityRecord>[])
              ListTile(
                title: Text(switch (record.kind) {
                  BackupIdentityKind.artifact =>
                    context.loc.settingsNostrKeysArtifactIdentity,
                  BackupIdentityKind.server =>
                    context.loc.settingsNostrKeysServerIdentity,
                }),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => NostrKeyDetailScreen.system(record),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> _create(BuildContext context) async {
    final cubit = context.read<NostrKeysCubit>();
    final record = await Navigator.of(context).push<NostrKeyRecord>(
      MaterialPageRoute(
        builder: (_) =>
            BlocProvider.value(value: cubit, child: const NostrKeyFormScreen()),
      ),
    );
    if (record != null && context.mounted) {
      SnackBarUtils.showSnackBar(context, context.loc.settingsNostrKeysCreated);
    }
  }

  Future<void> _toggleSystemKeys(
    BuildContext context,
    NostrKeysState state,
  ) async {
    final cubit = context.read<NostrKeysCubit>();
    if (state.systemKeys != null || state.loadingSystem) {
      cubit.hideSystemKeys();
      return;
    }
    var accepted = false;
    await WarningBottomSheet.show(
      context,
      title: context.loc.settingsNostrKeysSystemKeysWarningTitle,
      message: context.loc.settingsNostrKeysSystemKeysWarningMessage,
      confirmLabel: context.loc.settingsNostrKeysWarningUnderstand,
      onConfirm: () => accepted = true,
    );
    if (accepted && context.mounted) await cubit.showSystemKeys();
  }
}
