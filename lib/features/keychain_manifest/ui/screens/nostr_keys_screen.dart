import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/warning_bottom_sheet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/keychain_manifest_l10n.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/nostr_keys_cubit.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

final class NostrKeysScreen extends StatefulWidget {
  const NostrKeysScreen({super.key});

  @override
  State<NostrKeysScreen> createState() => _NostrKeysScreenState();
}

final class _NostrKeysScreenState extends State<NostrKeysScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NostrKeysCubit>().load();
  }

  Future<void> _openCreate() async {
    final created = await context.pushNamed<bool>(
      KeychainManifestRoutes.createName,
    );
    if (!mounted) return;
    await context.read<NostrKeysCubit>().load();
    if (mounted && created == true) {
      SnackBarUtils.showSnackBar(context, context.loc.settingsNostrKeysCreated);
    }
  }

  Future<void> _toggleSystemKeys(NostrKeysState state) async {
    final cubit = context.read<NostrKeysCubit>();
    if (state.showSystemKeys) {
      cubit.setShowSystemKeys(false);
      return;
    }
    await WarningBottomSheet.show(
      context,
      title: context.loc.settingsNostrKeysSystemKeysWarningTitle,
      message: context.loc.settingsNostrKeysSystemKeysWarningMessage,
      confirmLabel: context.loc.settingsNostrKeysWarningUnderstand,
      onConfirm: () => cubit.setShowSystemKeys(true),
    );
  }

  Future<void> _openDetail(KeychainManifestEntry entry) async {
    await context.pushNamed(KeychainManifestRoutes.detailName, extra: entry);
    if (mounted) await context.read<NostrKeysCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NostrKeysCubit, NostrKeysState>(
      listenWhen: (previous, current) => previous.failure != current.failure,
      listener: (context, state) {
        final failure = state.failure;
        if (failure != null) {
          SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
        }
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: Text(context.loc.settingsNostrKeysTitle)),
        body: SafeArea(
          child: state.loading
              ? const Center(child: CircularProgressIndicator())
              : _KeyList(
                  state: state,
                  onToggleSystem: _toggleSystemKeys,
                  onOpen: _openDetail,
                ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BBButton.big(
              label: context.loc.settingsNostrKeysCreate,
              onPressed: _openCreate,
              disabled: state.loading || state.busy,
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

final class _KeyList extends StatelessWidget {
  final NostrKeysState state;
  final Future<void> Function(NostrKeysState state) onToggleSystem;
  final Future<void> Function(KeychainManifestEntry entry) onOpen;

  const _KeyList({
    required this.state,
    required this.onToggleSystem,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (state.userKeys.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: BBText(
              context.loc.settingsNostrKeysEmpty,
              style: context.font.bodyMedium,
              color: context.appColors.textMuted,
              textAlign: TextAlign.center,
            ),
          ),
        for (final entry in state.userKeys) _entry(context, entry),
        if (state.showSystemKeys && state.systemKeys.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 24,
              bottom: 4,
            ),
            child: BBText(
              context.loc.settingsNostrKeysSystemKeysWarningTitle,
              style: context.font.labelSmall,
              color: context.appColors.textMuted,
            ),
          ),
          for (final entry in state.systemKeys) _entry(context, entry),
        ],
        if (state.systemKeys.isNotEmpty)
          Align(
            child: TextButton(
              onPressed: () => onToggleSystem(state),
              child: Text(
                state.showSystemKeys
                    ? context.loc.settingsNostrKeysHideSystemKeys
                    : context.loc.settingsNostrKeysShowSystemKeys,
                style: TextStyle(color: context.appColors.error),
              ),
            ),
          ),
      ],
    );
  }

  Widget _entry(BuildContext context, KeychainManifestEntry entry) {
    final system = entry.materializations.single as KeychainManifestNostrKey;
    return SettingsEntryItem(
      icon: system.keyKind == KeychainManifestNostrKeyKind.reserved
          ? Icons.settings_suggest
          : Icons.key,
      title: entry.displayName(context),
      iconColor: system.keyKind == KeychainManifestNostrKeyKind.reserved
          ? context.appColors.textMuted
          : null,
      textColor: system.keyKind == KeychainManifestNostrKeyKind.reserved
          ? context.appColors.textMuted
          : null,
      onTap: () => onOpen(entry),
    );
  }
}
