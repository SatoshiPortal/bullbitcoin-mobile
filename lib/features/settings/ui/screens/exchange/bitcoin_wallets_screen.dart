import 'package:bb_mobile/core/exchange/domain/entity/default_wallet_address.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/default_wallets_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangeBitcoinWalletsScreen extends StatelessWidget {
  const ExchangeBitcoinWalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => locator<DefaultWalletsCubit>()..loadWallets(),
      child: const _BitcoinWalletsView(),
    );
  }
}

class _BitcoinWalletsView extends StatelessWidget {
  const _BitcoinWalletsView();

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (DefaultWalletsCubit cubit) => cubit.state.isLoading,
    );
    final errorMessage = context.select(
      (DefaultWalletsCubit cubit) => cubit.state.errorMessage,
    );

    return Scaffold(
      backgroundColor: context.appColors.secondaryFixed,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.exchangeBitcoinWalletsTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? _buildErrorState(context, errorMessage)
                : _buildContent(context),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: context.appColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.read<DefaultWalletsCubit>().loadWallets(),
            child: Text(context.loc.recoverbullRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _WalletAddressField(addressType: WalletAddressType.bitcoin),
            const SizedBox(height: 24),
            _WalletAddressField(addressType: WalletAddressType.lightning),
            const SizedBox(height: 24),
            _WalletAddressField(addressType: WalletAddressType.liquid),
          ],
        ),
      ),
    );
  }
}

class _WalletAddressField extends StatelessWidget {
  final WalletAddressType addressType;

  const _WalletAddressField({required this.addressType});

  String _getLabel(BuildContext context) {
    switch (addressType) {
      case WalletAddressType.bitcoin:
        return context.loc.exchangeBitcoinWalletsBitcoinAddressLabel;
      case WalletAddressType.lightning:
        return context.loc.exchangeBitcoinWalletsLightningAddressLabel;
      case WalletAddressType.liquid:
        return context.loc.exchangeBitcoinWalletsLiquidAddressLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.select(
      (DefaultWalletsCubit cubit) => cubit.state,
    );
    final isEditing = state.editingAddressType == addressType;
    final isDeleting = state.deletingAddressType == addressType;
    final currentValue = state.getAddressValue(addressType);
    final existingWallet = state.getWallet(addressType);
    final hasExistingAddress = existingWallet?.hasAddress ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getLabel(context),
          style: context.font.labelMedium?.copyWith(
            color: context.appColors.secondary,
          ),
        ),
        const SizedBox(height: 12),
        BBInputText(
          value: currentValue,
          onChanged: (newValue) {
            context.read<DefaultWalletsCubit>().updateAddressValue(
                  addressType,
                  newValue,
                );
          },
          disabled: !isEditing,
          hint: currentValue.isEmpty
              ? context.loc.exchangeBitcoinWalletsEnterAddressHint
              : null,
          hintStyle: context.font.bodyMedium?.copyWith(
            color: context.appColors.surfaceContainer,
          ),
          rightIcon: _buildRightIcon(context, isEditing, hasExistingAddress),
          onRightTap: () => _handleRightTap(context, isEditing),
          style: context.font.bodyLarge?.copyWith(
            color: context.appColors.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isEditing) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () =>
                    context.read<DefaultWalletsCubit>().cancelEditing(),
                child: Text(context.loc.cancel),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: state.isSaving
                    ? null
                    : () => context
                        .read<DefaultWalletsCubit>()
                        .saveWallet(addressType),
                child: state.isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.loc.receiveSave),
              ),
            ],
          ),
        ],
        if (hasExistingAddress && !isEditing) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  context
                      .read<DefaultWalletsCubit>()
                      .setDeletingAddressType(addressType);
                },
                child: Text(
                  context.loc.delete,
                  style: TextStyle(color: context.appColors.error),
                ),
              ),
            ],
          ),
        ],
        if (isDeleting) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.loc.exchangeBitcoinWalletsDeleteConfirmation,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.error,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => context
                          .read<DefaultWalletsCubit>()
                          .setDeletingAddressType(null),
                      child: Text(context.loc.cancel),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appColors.error,
                      ),
                      onPressed: state.isSaving
                          ? null
                          : () => context
                              .read<DefaultWalletsCubit>()
                              .deleteWallet(addressType),
                      child: state.isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.loc.delete),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (state.hasSaveError && (isEditing || isDeleting)) ...[
          const SizedBox(height: 8),
          Text(
            state.saveErrorMessage!,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRightIcon(
    BuildContext context,
    bool isEditing,
    bool hasExistingAddress,
  ) {
    if (isEditing) {
      return const SizedBox.shrink();
    }
    return Icon(
      Icons.edit,
      size: 20,
      color: context.appColors.outline,
    );
  }

  void _handleRightTap(BuildContext context, bool isEditing) {
    if (!isEditing) {
      context.read<DefaultWalletsCubit>().setEditingAddressType(addressType);
    }
  }
}
