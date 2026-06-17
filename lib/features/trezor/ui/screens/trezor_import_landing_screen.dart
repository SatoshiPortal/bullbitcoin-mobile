import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dropdown/selectable_list.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/public/import_watch_only_facade.dart';
import 'package:bb_mobile/features/trezor/domain/trezor_capabilities.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_import_cubit.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Flow:
///   1. User picks wallet type (BIP84/49/44), taps "Start Import".
///   2. We fetch account 0 from Trezor (one deeplink round-trip).
///   3. Master fingerprint is parsed from the returned descriptor field —
///      no separate deeplink for path "m" (Trezor refuses that).
///   4. We build a `WatchOnlyDescriptorEntity` flagged `trezor` and push
///      to the existing watch-only finalize screen, which shows the
///      descriptor + label + Import button.
class TrezorImportLandingScreen extends StatelessWidget {
  const TrezorImportLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TrezorImportCubit>(
      create: (_) => locator<TrezorImportCubit>(),
      child: const _TrezorImportLandingView(),
    );
  }
}

class _TrezorImportLandingView extends StatefulWidget {
  const _TrezorImportLandingView();

  @override
  State<_TrezorImportLandingView> createState() =>
      __TrezorImportLandingViewState();
}

class __TrezorImportLandingViewState extends State<_TrezorImportLandingView> {
  ScriptType _selectedScriptType =
      kTrezorSupportedScriptTypes.contains(ScriptType.bip84)
      ? ScriptType.bip84
      : kTrezorSupportedScriptTypes.first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.trezorImportTitle,
          color: context.appColors.background,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
      body:
          BlocConsumer<
            TrezorImportCubit,
            TrezorOperationState<WatchOnlyDescriptorEntity>
          >(
            listener: (context, state) {
              if (state.isSuccess && state.result != null) {
                // Reset BEFORE navigating so a back-nav + retry starts fresh
                // and the pushed-onto screen never observes a stale "success"
                // state from this cubit. Matches `LedgerActionScreen`'s order.
                context.read<TrezorImportCubit>().reset();
                context.pushNamed(
                  ImportWatchOnlyWalletRoutes.import.name,
                  extra: state.result as WatchOnlyDescriptorEntity,
                );
              } else if (state.isError) {
                SnackBarUtils.showSnackBar(
                  context,
                  state.error?.toTranslated(context) ??
                      context.loc.trezorImportErrorSnackbarFallback,
                );
              }
            },
            builder: (context, state) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Center(
                  child: Column(
                    children: [
                      const Gap(32),
                      _buildMainContent(context, state),
                      const Gap(32),
                      _buildActionButtons(context, state),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  // ───────────────────────── Sub-builders ─────────────────────────

  Widget _buildMainContent(BuildContext context, TrezorOperationState state) {
    return Column(
      children: [
        _buildIconForState(context, state),
        const Gap(24),
        BBText(
          _getMainTextForState(context, state),
          textAlign: TextAlign.center,
          style: context.font.bodyLarge,
        ),
        const Gap(16),
        BBText(
          _getSubTextForState(context, state),
          textAlign: TextAlign.center,
          color: context.appColors.textMuted,
          style: context.font.bodyMedium,
        ),
        if (state.isInitial)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _buildScriptTypeButton(context),
          ),
      ],
    );
  }

  Widget _buildIconForState(BuildContext context, TrezorOperationState state) {
    if (state.isInitial) {
      return Icon(
        Icons.memory_outlined,
        size: 60,
        color: context.appColors.primary,
      );
    }

    if (state.isLaunching || state.isWaiting) {
      return SizedBox(
        width: 80,
        height: 80,
        child: CircularProgressIndicator(
          color: context.appColors.primary,
          strokeWidth: 3,
        ),
      );
    }

    if (state.isError) {
      return Icon(Icons.error, size: 80, color: context.appColors.error);
    }

    // Success path: the listener navigates away within the same frame.
    return const SizedBox.shrink();
  }

  Widget _buildActionButtons(BuildContext context, TrezorOperationState state) {
    return Column(
      children: [
        if (state.isInitial)
          BBButton.big(
            onPressed: () => _startImport(context),
            label: context.loc.trezorImportStartButton,
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
        if (state.isError)
          BBButton.big(
            onPressed: () => context.read<TrezorImportCubit>().reset(),
            label: context.loc.trezorTryAgain,
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
      ],
    );
  }

  Widget _buildScriptTypeButton(BuildContext context) {
    return Column(
      children: [
        BBText(
          context.loc.trezorImportWalletTypeLabel,
          style: context.font.bodyMedium,
          color: context.appColors.textMuted,
        ),
        const Gap(12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appColors.border, width: 1),
          ),
          child: Material(
            color: context.appColors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showScriptTypeSelection(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: BBText(
                        _getScriptTypeDisplayName(context, _selectedScriptType),
                        style: context.font.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: context.appColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Helpers ─────────────────────────

  String _getMainTextForState(BuildContext context, TrezorOperationState state) {
    if (state.isLaunching || state.isWaiting) {
      return context.loc.trezorImportWaitingTitle;
    }
    if (state.isError) {
      return context.loc.trezorImportFailedTitle;
    }
    return context.loc.trezorImportInitialTitle;
  }

  String _getSubTextForState(BuildContext context, TrezorOperationState state) {
    if (state.isLaunching || state.isWaiting) {
      return context.loc.trezorImportWaitingSubtitle;
    }
    if (state.isError) {
      return state.error?.toTranslated(context) ??
          context.loc.trezorImportFailedFallback;
    }
    return context.loc.trezorImportInitialSubtitle;
  }

  String _getScriptTypeDisplayName(
    BuildContext context,
    ScriptType scriptType,
  ) => switch (scriptType) {
    ScriptType.bip84 => context.loc.trezorScriptTypeBip84Title,
    ScriptType.bip49 => context.loc.trezorScriptTypeBip49Title,
    ScriptType.bip44 => context.loc.trezorScriptTypeBip44Title,
  };

  // ───────────────────────── Actions ─────────────────────────

  // Build the dropdown from kTrezorSupportedScriptTypes so adding or
  // removing a Trezor-supported script type happens in one place
  // (lib/features/trezor/domain/trezor_capabilities.dart) and
  // automatically updates the visible options here.
  Future<void> _showScriptTypeSelection(BuildContext context) async {
    final scriptTypeItems = <SelectableListItem>[
      if (kTrezorSupportedScriptTypes.contains(ScriptType.bip84))
        SelectableListItem(
          value: 'bip84',
          title: context.loc.trezorScriptTypeBip84Title,
          subtitle1: context.loc.trezorScriptTypeBip84Subtitle,
          subtitle2: '',
        ),
      if (kTrezorSupportedScriptTypes.contains(ScriptType.bip49))
        SelectableListItem(
          value: 'bip49',
          title: context.loc.trezorScriptTypeBip49Title,
          subtitle1: context.loc.trezorScriptTypeBip49Subtitle,
          subtitle2: '',
        ),
      if (kTrezorSupportedScriptTypes.contains(ScriptType.bip44))
        SelectableListItem(
          value: 'bip44',
          title: context.loc.trezorScriptTypeBip44Title,
          subtitle1: context.loc.trezorScriptTypeBip44Subtitle,
          subtitle2: '',
        ),
    ];

    final selected = await BlurredBottomSheet.show<String>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(16),
                BBText(
                  context.loc.trezorImportWalletTypeBottomSheetTitle,
                  style: context.font.headlineMedium,
                ),
                const Gap(16),
                SelectableList(
                  selectedValue: _selectedScriptType.name,
                  items: scriptTypeItems,
                ),
                const Gap(24),
              ],
            ),
          ),
        ),
      ),
    );

    if (selected != null) {
      final next = ScriptType.fromName(selected);
      if (next != _selectedScriptType) {
        setState(() => _selectedScriptType = next);
      }
    }
  }

  Future<void> _startImport(BuildContext context) async {
    try {
      await context.read<TrezorImportCubit>().startImport(
        scriptType: _selectedScriptType,
        // For now, Trezor import is mainnet-only.
        isTestnet: false,
      );
    } catch (_) {
      // Cubit already emitted an error state; the BlocConsumer listener
      // shows the snackbar. Swallow here to prevent uncaught futures.
    }
  }
}
