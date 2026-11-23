import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/dca/public/dca_facade.dart' show DcaRoute;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:primitives/primitives.dart' show FormatAmount;
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullConfirmDialog, BullSwitch, BullTypographyX, Gap;
import 'package:go_router/go_router.dart';

class DcaListTile extends StatefulWidget {
  const DcaListTile({super.key, required this.hasDcaActive, required this.dca});

  final bool hasDcaActive;
  final UserDca? dca;

  @override
  State<DcaListTile> createState() => _DcaListTileState();
}

class _DcaListTileState extends State<DcaListTile> {
  bool _showSettings = false;

  Widget? _buildDcaContent(UserDca dca, BuildContext context) {
    if (dca.amount == null ||
        dca.currency == null ||
        dca.frequency == null ||
        dca.network == null ||
        dca.address == null) {
      return Text(
        context.loc.exchangeDcaUnableToGetConfig,
        style: TextStyle(
          color: context.appColors.onSurface.withValues(alpha: 0.6),
        ),
      );
    }

    return DcaSettingsContent(
      amount: dca.amount!,
      currency: dca.currency!,
      frequency: dca.frequency!,
      network: dca.network!,
      address: dca.address!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [
                Text(
                  widget.hasDcaActive
                      ? context.loc.exchangeDcaDeactivateTitle
                      : context.loc.exchangeDcaActivateTitle,
                ),
                if (widget.hasDcaActive) ...[
                  const Gap(4),
                  GestureDetector(
                    onTap: () => setState(() => _showSettings = !_showSettings),
                    child: Text(
                      _showSettings
                          ? context.loc.exchangeDcaHideSettings
                          : context.loc.exchangeDcaViewSettings,
                      style: context.bullType.label.copyWith(
                        fontWeight: FontWeight.w400,
                        color: context.appColors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: context.appColors.primary,
                      ),
                    ),
                  ),
                  const Gap(4),
                ],
              ],
            ),
          ),
          BullSwitch(
            value: widget.hasDcaActive,
            onChanged: (value) {
              if (value) {
                // Activate DCA
                context.pushNamed(DcaRoute.dca.name);
              } else {
                // Deactivate DCA - show confirmation dialog
                _confirmStopDca(context);
              }
            },
          ),
        ],
      ),
      subtitle: widget.hasDcaActive && _showSettings
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildDcaContent(widget.dca!, context),
            )
          : null,
    );
  }

  Future<void> _confirmStopDca(BuildContext context) async {
    final confirmed = await BullConfirmDialog.show(
      context,
      title: context.loc.exchangeDcaCancelDialogTitle,
      message: context.loc.exchangeDcaCancelDialogMessage,
      confirmLabel: context.loc.exchangeDcaCancelDialogConfirmButton,
      cancelLabel: context.loc.exchangeDcaCancelDialogCancelButton,
      destructive: true,
    );
    if (confirmed && context.mounted) {
      await context.read<ExchangeCubit>().stopDca();
    }
  }
}

class DcaSettingsContent extends StatelessWidget {
  const DcaSettingsContent({
    super.key,
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.network,
    required this.address,
  });

  final double amount;
  final FiatCurrency currency;
  final DcaBuyFrequency frequency;
  final DcaNetwork network;
  final String address;

  @override
  Widget build(BuildContext context) {
    final frequency = switch (this.frequency) {
      DcaBuyFrequency.hourly => context.loc.exchangeDcaFrequencyHour,
      DcaBuyFrequency.daily => context.loc.exchangeDcaFrequencyDay,
      DcaBuyFrequency.weekly => context.loc.exchangeDcaFrequencyWeek,
      DcaBuyFrequency.monthly => context.loc.exchangeDcaFrequencyMonth,
    };
    final network = switch (this.network) {
      DcaNetwork.bitcoin => context.loc.exchangeDcaNetworkBitcoin,
      DcaNetwork.lightning => context.loc.exchangeDcaNetworkLightning,
      DcaNetwork.liquid => context.loc.exchangeDcaNetworkLiquid,
    };
    final addressLabel = switch (this.network) {
      DcaNetwork.bitcoin => context.loc.exchangeDcaAddressLabelBitcoin,
      DcaNetwork.lightning => context.loc.exchangeDcaAddressLabelLightning,
      DcaNetwork.liquid => context.loc.exchangeDcaAddressLabelLiquid,
    };

    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          context.loc.exchangeDcaSummaryMessage(
            FormatAmount.fiat(amount, currency.code),
            frequency,
            network,
          ),
          style: context.bullType.body,
        ),
        const Gap(8),
        Text(
          context.loc.exchangeDcaAddressDisplay(addressLabel, address),
          style: context.bullType.body,
        ),
      ],
    );
  }
}
