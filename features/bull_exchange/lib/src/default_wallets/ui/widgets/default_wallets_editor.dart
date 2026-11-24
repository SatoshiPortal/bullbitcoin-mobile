import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/default_wallets/presentation/default_wallets_cubit.dart';
import 'package:bull_exchange/src/default_wallets/presentation/default_wallets_failure_l10n.dart';
import 'package:bull_exchange/src/default_wallets/presentation/default_wallets_state.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../default_wallets_payout_fields.dart';
import '../../domain/validate_default_wallet_destination_usecase.dart';

typedef DefaultWalletsFooterBuilder = Widget Function(
  BuildContext context,
  DefaultWallets wallets,
  ({bool isLoading, bool isSaving, bool isEditing}) status,
);

class DefaultWalletsEditor extends StatelessWidget {
  final Exchange exchange;
  final DefaultWalletsPayoutFields payoutFields;
  final bool? showDescription;
  final EdgeInsetsGeometry? padding;
  final DefaultWalletsFooterBuilder? footerBuilder;

  const DefaultWalletsEditor({
    required this.exchange,
    required this.payoutFields,
    this.showDescription,
    this.padding,
    this.footerBuilder,
    super.key,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => DefaultWalletsCubit(
      exchange: exchange,
      validateDestination: ValidateDefaultWalletDestinationUsecase(
        payoutFields.validate,
      ),
    )..init(),
    child: BlocListener<DefaultWalletsCubit, DefaultWalletsState>(
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
        payoutFields: payoutFields,
        showDescription: showDescription,
        padding: padding,
        footerBuilder: footerBuilder,
      ),
    ),
  );
}

class _EditorContent extends StatelessWidget {
  static const _defaultPadding = EdgeInsets.all(16);

  final bool? showDescription;
  final EdgeInsetsGeometry? padding;
  final DefaultWalletsFooterBuilder? footerBuilder;
  final DefaultWalletsPayoutFields payoutFields;

  const _EditorContent({
    required this.payoutFields,
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
            BullButton.secondary(
              label: context.loc.retry,
              onPressed: () => context.read<DefaultWalletsCubit>().init(),
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
                payoutFields: payoutFields,
                type: WalletAddressType.bitcoin,
                label: context.loc.exchangeBitcoinWalletsBitcoinAddressLabel,
              ),
              const SizedBox(height: 24),
              _WalletAddressField(
                payoutFields: payoutFields,
                type: WalletAddressType.lightning,
                label: context.loc.exchangeBitcoinWalletsLightningAddressLabel,
              ),
              const SizedBox(height: 24),
              _WalletAddressField(
                payoutFields: payoutFields,
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
  final DefaultWalletsPayoutFields payoutFields;

  const _WalletAddressField({
    required this.type,
    required this.label,
    required this.payoutFields,
  });

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
              BullButton.secondary(
                label: context.loc.delete,
                onPressed: state.isSaving
                    ? null
                    : () => cubit.deleteWallet(type),
                size: BullButtonSize.small,
                compact: true,
              ),
          ],
        ),
        const SizedBox(height: 8),
        widget.payoutFields.buildField(
          type: type,
          value: isEditing ? inputValue : currentAddress,
          hint: context.loc.exchangeBitcoinWalletsEnterAddressHint,
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
                child: BullButton.secondary(
                  label: context.loc.cancel,
                  onPressed: (isSaving) ? null : () => cubit.cancelEditing(),
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
                    : BullButton.primary(
                        label: context.loc.save,
                        onPressed: (!_isValid)
                            ? null
                            : () => cubit.saveWallet(type),
                      ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
