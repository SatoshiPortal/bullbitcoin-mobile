import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bb_mobile/features/dca/ui/dca_router.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
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

  void _toggleDca(bool value) {
    if (value) {
      context.pushNamed(DcaRoute.dca.name);
    } else {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: context.appColors.background,
            title: Text(context.loc.exchangeDcaCancelDialogTitle),
            content: Text(context.loc.exchangeDcaCancelDialogMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(context.loc.exchangeDcaCancelDialogCancelButton),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.read<ExchangeCubit>().stopDca();
                },
                child: Text(context.loc.exchangeDcaCancelDialogConfirmButton),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: context.appColors.border.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleDca(!widget.hasDcaActive),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.repeat,
                    size: 18,
                    color: widget.hasDcaActive
                        ? context.appColors.primary
                        : context.appColors.textMuted,
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BBText(
                          widget.hasDcaActive
                              ? context.loc.exchangeDcaDeactivateTitle
                              : context.loc.exchangeDcaActivateTitle,
                          style: context.font.bodyMedium,
                          color: context.appColors.text,
                        ),
                        if (widget.hasDcaActive && widget.dca != null)
                          BBText(
                            _getDcaSummary(widget.dca!, context),
                            style: context.font.labelSmall,
                            color: context.appColors.textMuted,
                          ),
                      ],
                    ),
                  ),
                  const Gap(8),
                  Switch(
                    value: widget.hasDcaActive,
                    onChanged: _toggleDca,
                    activeTrackColor: context.appColors.primary.withValues(alpha: 0.5),
                    activeThumbColor: context.appColors.primary,
                  ),
                ],
              ),
            ),
          ),
          if (widget.hasDcaActive && widget.dca != null) ...[
            Divider(
              height: 1,
              thickness: 0.5,
              color: context.appColors.border.withValues(alpha: 0.2),
            ),
            InkWell(
              onTap: () => setState(() => _showSettings = !_showSettings),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BBText(
                      _showSettings
                          ? context.loc.exchangeDcaHideSettings
                          : context.loc.exchangeDcaViewSettings,
                      style: context.font.labelSmall,
                      color: context.appColors.primary,
                    ),
                    const Gap(4),
                    Icon(
                      _showSettings
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 14,
                      color: context.appColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            if (_showSettings)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: DcaSettingsContent(
                  amount: widget.dca!.amount!,
                  currency: widget.dca!.currency!,
                  frequency: widget.dca!.frequency!,
                  network: widget.dca!.network!,
                  address: widget.dca!.address!,
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _getDcaSummary(UserDca dca, BuildContext context) {
    if (dca.amount == null || dca.currency == null || dca.frequency == null) {
      return '';
    }
    final frequency = switch (dca.frequency!) {
      DcaBuyFrequency.hourly => 'hourly',
      DcaBuyFrequency.daily => 'daily',
      DcaBuyFrequency.weekly => 'weekly',
      DcaBuyFrequency.monthly => 'monthly',
    };
    return '${FormatAmount.fiat(dca.amount!, dca.currency!.code)} $frequency';
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
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Gap(8),
        Text(
          context.loc.exchangeDcaAddressDisplay(addressLabel, address),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
