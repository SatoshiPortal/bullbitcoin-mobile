import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/default_wallets/presentation/default_wallets_cubit.dart';
import 'package:bb_mobile/features/default_wallets/presentation/default_wallets_state.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_view_data.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef DefaultWalletsFooterBuilder =
    Widget Function(BuildContext context, DefaultWalletsViewData wallets);

class DefaultWalletsEditor extends StatelessWidget {
  final bool showDescription;
  final EdgeInsetsGeometry padding;
  final DefaultWalletsFooterBuilder? footerBuilder;

  const DefaultWalletsEditor({
    this.showDescription = true,
    this.padding = const EdgeInsets.all(16),
    this.footerBuilder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<DefaultWalletsCubit, DefaultWalletsState>(
      listenWhen: (previous, current) =>
          (!previous.saveSuccess && current.saveSuccess) ||
          (previous.saveError == null && current.saveError != null),
      listener: (context, state) {
        if (state.saveSuccess) {
          SnackBarUtils.showSnackBar(
            context,
            context.loc.exchangeBitcoinWalletsSaveSuccess,
          );
        } else if (state.saveError != null) {
          SnackBarUtils.showSnackBar(context, state.saveError!);
        }
      },
      child: _EditorContent(
        showDescription: showDescription,
        padding: padding,
        footerBuilder: footerBuilder,
      ),
    );
  }
}

class _EditorContent extends StatelessWidget {
  final bool showDescription;
  final EdgeInsetsGeometry padding;
  final DefaultWalletsFooterBuilder? footerBuilder;

  const _EditorContent({
    required this.showDescription,
    required this.padding,
    required this.footerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DefaultWalletsCubit>().state;

    return Column(
      children: [
        if (state.isLoading)
          LinearProgressIndicator(
            backgroundColor: context.appColors.surface,
            color: context.appColors.primary,
          ),
        Expanded(child: _buildContent(context, state)),
      ],
    );
  }

  Widget _buildContent(BuildContext context, DefaultWalletsState state) {
    if (state.isLoading &&
        state.loadError == null &&
        state.defaultWallets == null) {
      return const SizedBox.shrink();
    }

    if (state.loadError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BBText(
              state.loadError!,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.error,
              ),
            ),
            const SizedBox(height: 16),
            BBButton.big(
              label: context.loc.retry,
              onPressed: () => context.read<DefaultWalletsCubit>().init(),
              bgColor: context.appColors.onSurface,
              textColor: context.appColors.surface,
            ),
          ],
        ),
      );
    }

    final wallets = DefaultWalletsViewData(
      bitcoinAddress: state.currentBitcoinAddress,
      lightningAddress: state.currentLightningAddress,
      liquidAddress: state.currentLiquidAddress,
      isLoading: state.isLoading,
      isSaving: state.isSaving,
      isEditing: state.isEditing,
    );

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showDescription) ...[
                BBText(
                  context.loc.exchangeBitcoinWalletsDescription,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.outline,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              _WalletAddressField(
                type: WalletAddressType.bitcoin,
                label: context.loc.exchangeBitcoinWalletsBitcoinAddressLabel,
              ),
              const SizedBox(height: 24),
              _WalletAddressField(
                type: WalletAddressType.lightning,
                label: context.loc.exchangeBitcoinWalletsLightningAddressLabel,
              ),
              const SizedBox(height: 24),
              _WalletAddressField(
                type: WalletAddressType.liquid,
                label: context.loc.exchangeBitcoinWalletsLiquidAddressLabel,
              ),
              if (footerBuilder case final builder?) ...[
                const SizedBox(height: 24),
                builder(context, wallets),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletAddressField extends StatelessWidget {
  final WalletAddressType type;
  final String label;

  const _WalletAddressField({required this.type, required this.label});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DefaultWalletsCubit>().state;
    final cubit = context.read<DefaultWalletsCubit>();

    final isEditing = state.editingWalletType == type;
    final inputValue = state.getInputValue(type);
    final currentAddress = state.getCurrentAddress(type);
    final hasAddress = currentAddress.isNotEmpty;
    final isSaving = state.isSaving && isEditing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: BBText(
                label,
                style: context.font.labelMedium?.copyWith(
                  color: context.appColors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (hasAddress && !isEditing)
              TextButton(
                onPressed: isSaving ? null : () => cubit.deleteWallet(type),
                child: BBText(
                  context.loc.delete,
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.error,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (isEditing) ...[
          BullInputText(
            value: inputValue,
            onChanged: (value) => cubit.updateAddress(type, value),
            hint: type.addressHint,
            hintStyle: context.font.bodyMedium?.copyWith(
              color: context.appColors.textMuted,
            ),
            style: context.font.bodyLarge?.copyWith(
              color: context.appColors.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BBButton.big(
                  label: context.loc.cancel,
                  onPressed: () => cubit.cancelEditing(),
                  disabled: isSaving,
                  bgColor: context.appColors.surfaceContainerHighest,
                  textColor: context.appColors.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: isSaving
                    ? Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: context.appColors.onSurface,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.appColors.surface,
                            ),
                          ),
                        ),
                      )
                    : BBButton.big(
                        label: context.loc.save,
                        onPressed: () => cubit.saveWallet(type),
                        bgColor: context.appColors.onSurface,
                        textColor: context.appColors.surface,
                      ),
              ),
            ],
          ),
        ] else ...[
          GestureDetector(
            onTap: () => cubit.startEditing(type),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: context.appColors.overlay.withValues(alpha: 0.05),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: hasAddress
                        ? AddressViewer(
                            currentAddress,
                            style: context.font.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            color: context.appColors.onSurface,
                          )
                        : BBText(
                            context.loc.exchangeBitcoinWalletsEnterAddressHint,
                            style: context.font.bodyMedium?.copyWith(
                              color: context.appColors.textMuted,
                            ),
                          ),
                  ),
                  Icon(
                    Icons.edit,
                    size: 20,
                    color: context.appColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
