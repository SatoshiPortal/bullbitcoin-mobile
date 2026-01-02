import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/default_wallets_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/default_wallets_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangeBitcoinWalletsScreen extends StatefulWidget {
  const ExchangeBitcoinWalletsScreen({super.key});

  @override
  State<ExchangeBitcoinWalletsScreen> createState() =>
      _ExchangeBitcoinWalletsScreenState();
}

class _ExchangeBitcoinWalletsScreenState
    extends State<ExchangeBitcoinWalletsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DefaultWalletsCubit>().init();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DefaultWalletsCubit, DefaultWalletsState>(
      listenWhen: (previous, current) =>
          (!previous.saveSuccess && current.saveSuccess) ||
          (previous.saveError == null && current.saveError != null),
      listener: (context, state) {
        if (state.saveSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.loc.exchangeBitcoinWalletsSaveSuccess,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.appColors.surfaceFixed,
                ),
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: context.appColors.onSurface.withAlpha(204),
              behavior: SnackBarBehavior.floating,
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 100, left: 40, right: 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        } else if (state.saveError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.saveError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.appColors.surfaceFixed,
                ),
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: context.appColors.error,
              behavior: SnackBarBehavior.floating,
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 100, left: 40, right: 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: context.loc.exchangeBitcoinWalletsTitle,
            onBack: () => context.pop(),
          ),
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final state = context.watch<DefaultWalletsCubit>().state;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
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

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BBText(
                context.loc.exchangeBitcoinWalletsDescription,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.outline,
                ),
              ),
              const SizedBox(height: 24),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletAddressField extends StatelessWidget {
  const _WalletAddressField({required this.type, required this.label});

  final WalletAddressType type;
  final String label;

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
          BBInputText(
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
                        ? BBText(
                            _truncateAddress(currentAddress),
                            style: context.font.bodyLarge?.copyWith(
                              color: context.appColors.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
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

  String _truncateAddress(String address) {
    if (address.length <= 20) return address;
    return '${address.substring(0, 10)}...${address.substring(address.length - 8)}';
  }
}
