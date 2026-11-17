import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet/public/payment_destination.dart';
import 'package:bb_mobile/features/default_wallets/presentation/default_wallets_cubit.dart';
import 'package:bb_mobile/features/default_wallets/presentation/default_wallets_failure_l10n.dart';
import 'package:bb_mobile/features/default_wallets/presentation/default_wallets_state.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef DefaultWalletsFooterBuilder = Widget Function(
  BuildContext context,
  DefaultWallets wallets,
  ({bool isLoading, bool isSaving, bool isEditing}) status,
);

class DefaultWalletsEditor extends StatelessWidget {
  final bool? showDescription;
  final EdgeInsetsGeometry? padding;
  final DefaultWalletsFooterBuilder? footerBuilder;

  const DefaultWalletsEditor({
    this.showDescription,
    this.padding,
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
        if (state.saveError case final error?) {
          BullSnackBar.show(context, message: error.toTranslated(context));
        } else if (state.saveSuccess) {
          BullSnackBar.show(
            context,
            message: context.loc.exchangeBitcoinWalletsSaveSuccess,
          );
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
  static const _defaultPadding = EdgeInsets.all(16);

  final bool? showDescription;
  final EdgeInsetsGeometry? padding;
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

    if (state.loadError case final error?) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BullText(
              error.toTranslated(context),
              style: context.bullType.body.copyWith(
                color: context.appColors.error,
              ),
            ),
            const SizedBox(height: 16),
            BullButton.big(
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
          padding: padding ?? _defaultPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showDescription ?? true) ...[
                BullText(
                  context.loc.exchangeBitcoinWalletsDescription,
                  style: context.bullType.body.copyWith(
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
                builder(
                  context,
                  state.defaultWallets ?? const DefaultWallets(),
                  (
                    isLoading: state.isLoading,
                    isSaving: state.isSaving,
                    isEditing: state.isEditing,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletAddressField extends StatefulWidget {
  final WalletAddressType type;
  final String label;

  const _WalletAddressField({required this.type, required this.label});

  @override
  State<_WalletAddressField> createState() => _WalletAddressFieldState();
}

class _WalletAddressFieldState extends State<_WalletAddressField> {
  bool _isValid = false;

  WalletAddressType get type => widget.type;
  String get label => widget.label;

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
              child: BullText(
                label,
                style: context.bullType.body.copyWith(
                  color: context.appColors.onSurface,
                ),
              ),
            ),
            if (hasAddress && !isEditing)
              TextButton(
                onPressed: state.isSaving
                    ? null
                    : () => cubit.deleteWallet(type),
                child: BullText(
                  context.loc.delete,
                  style: context.bullType.label
                      .copyWith(fontWeight: FontWeight.w400)
                      .copyWith(color: context.appColors.error),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        PaymentDestinationField(
          value: isEditing ? inputValue : currentAddress,
          hint: context.loc.exchangeBitcoinWalletsEnterAddressHint,
          acceptedTypes: {
            switch (type) {
              WalletAddressType.bitcoin => PaymentDestinationType.bitcoin,
              WalletAddressType.liquid => PaymentDestinationType.liquid,
              WalletAddressType.lightning =>
                PaymentDestinationType.lightningAddress,
            },
          },
          keyboardType: type == WalletAddressType.lightning
              ? TextInputType.emailAddress
              : TextInputType.text,
          enabled: !state.isSaving,
          onChanged: (value) {
            if (!isEditing) cubit.startEditing(type);
            setState(() => _isValid = false);
            cubit.updateAddress(type, value);
          },
          onValidationChanged: (isValid) {
            if (_isValid != isValid) setState(() => _isValid = isValid);
          },
        ),
        if (isEditing) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BullButton.big(
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
                          borderRadius: BorderRadius.circular(
                            context.bullShapes.button,
                          ),
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
                    : BullButton.big(
                        label: context.loc.save,
                        onPressed: () => cubit.saveWallet(type),
                        disabled: !_isValid,
                        bgColor: context.appColors.onSurface,
                        textColor: context.appColors.surface,
                      ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
