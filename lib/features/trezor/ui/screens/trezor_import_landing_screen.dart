import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dropdown/selectable_list.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/public/import_watch_only_facade.dart';
import 'package:bb_mobile/features/trezor/application/usecases/get_trezor_accounts_usecase.dart';
import 'package:bb_mobile/features/trezor/application/usecases/prepare_trezor_import_usecase.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_cubit.dart';
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
    return BlocProvider(
      create: (_) => locator<TrezorOperationCubit>(),
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
  ScriptType _selectedScriptType = ScriptType.bip84;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Import Trezor Wallet',
          color: context.appColors.background,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<TrezorOperationCubit, TrezorOperationState>(
        listener: (context, state) {
          if (state.isSuccess && state.result is WatchOnlyDescriptorEntity) {
            // Reset BEFORE navigating so a back-nav + retry starts fresh
            // and the pushed-onto screen never observes a stale "success"
            // state from this cubit. Matches `LedgerActionScreen`'s order.
            context.read<TrezorOperationCubit>().reset();
            context.pushNamed(
              ImportWatchOnlyWalletRoutes.import.name,
              extra: state.result as WatchOnlyDescriptorEntity,
            );
          } else if (state.isError) {
            SnackBarUtils.showSnackBar(
              context,
              _getErrorMessage(context, state.errorMessage),
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
          _getMainTextForState(state),
          textAlign: TextAlign.center,
          style: context.font.bodyLarge,
        ),
        const Gap(16),
        BBText(
          _getSubTextForState(state),
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

    if (state.isProcessing) {
      return Icon(Icons.download, size: 80, color: context.appColors.primary);
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
            label: 'Start Import',
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
        if (state.isError)
          BBButton.big(
            onPressed: () => context.read<TrezorOperationCubit>().reset(),
            label: 'Try Again',
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
          'Wallet Type:',
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
                        _getScriptTypeDisplayName(_selectedScriptType),
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

  // TODO: all of these resolve hardcoded English. Migrate
  // once ARB keys are added.

  String _getMainTextForState(TrezorOperationState state) {
    if (state.isLaunching || state.isWaiting) {
      return 'Confirm in Trezor Suite';
    }
    if (state.isProcessing) {
      return 'Importing…';
    }
    if (state.isError) {
      return 'Import Failed';
    }
    return 'Connect Your Trezor';
  }

  String _getSubTextForState(TrezorOperationState state) {
    if (state.isLaunching || state.isWaiting) {
      return 'Confirm the export request in Trezor Suite '
          'to share your account public key.';
    }
    if (state.isProcessing) {
      return 'Preparing your wallet…';
    }
    if (state.isError) {
      return state.errorMessage ?? 'Tap Try Again to start over.';
    }
    return 'Make sure Trezor Suite is installed on this device. '
        "You'll be redirected to authorize exporting your public key.";
  }

  String _getScriptTypeDisplayName(ScriptType scriptType) =>
      switch (scriptType) {
        ScriptType.bip84 => 'Segwit (BIP84)',
        ScriptType.bip49 => 'Nested Segwit (BIP49)',
        ScriptType.bip44 => 'Legacy (BIP44)',
      };

  String _getErrorMessage(BuildContext context, String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) {
      return 'Something went wrong. Try again.';
    }
    return errorMessage;
  }

  // ───────────────────────── Actions ─────────────────────────

  Future<void> _showScriptTypeSelection(BuildContext context) async {
    final scriptTypeItems = const [
      SelectableListItem(
        value: 'bip84',
        title: 'Segwit (BIP84)',
        subtitle1: 'Native SegWit — Recommended',
        subtitle2: '',
      ),
      SelectableListItem(
        value: 'bip49',
        title: 'Nested Segwit (BIP49)',
        subtitle1: 'P2WPKH-nested-in-P2SH',
        subtitle2: '',
      ),
      SelectableListItem(
        value: 'bip44',
        title: 'Legacy (BIP44)',
        subtitle1: 'P2PKH — Older format',
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
                  'Select Wallet Type',
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
    final cubit = context.read<TrezorOperationCubit>();
    final scriptType = _selectedScriptType;
    try {
      await cubit.executeOperation(() async {
        // Fetch account 0 for the selected derivation family. The master
        // fingerprint is parsed from the returned descriptor — no second
        // deeplink call for path "m" (Trezor refuses that).
        final accounts = await locator<GetTrezorAccountsUsecase>().execute(
          startIndex: 0,
          count: 1,
          scriptType: scriptType,
        );
        if (accounts.isEmpty) {
          throw Exception('Trezor returned no accounts');
        }
        return await locator<PrepareTrezorImportUsecase>().execute(
          account: accounts.first,
        );
      });
    } catch (_) {
      // Cubit already emitted an error state; the BlocConsumer listener
      // shows the snackbar. Swallow here to prevent uncaught futures.
    }
  }
}
