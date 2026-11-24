import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/pay/presentation/pay_bloc.dart';
import 'package:bull_exchange/src/pay/ui/widgets/pay_coin_selection_bottom_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBottomSheet,
        BullButton,
        BullShapesX,
        BullText,
        Gap,
        BullTypographyX;
import 'package:go_router/go_router.dart';

class PayAdvancedOptionsBottomSheet extends StatelessWidget {
  const PayAdvancedOptionsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isRBFEnabled = context.select(
      (PayBloc bloc) => (bloc.state as PayPaymentState).replaceByFee,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.bullShapes.sheet),
        ),
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: BullText(
                  context.loc.payAdvancedOptions,
                  style: context.bullType.subtitle.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                child: IconButton(
                  iconSize: 24,
                  icon: const Icon(Icons.close),
                  onPressed: context.pop,
                ),
              ),
            ],
          ),
          const Gap(32),
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              BullText(
                context.loc.payRbfActivated,
                style: context.bullType.subtitle.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Switch(
                value: isRBFEnabled,
                onChanged: (val) {
                  context.read<PayBloc>().add(
                    PayEvent.replaceByFeeChanged(replaceByFee: val),
                  );
                },
              ),
            ],
          ),
          const Gap(24),
          ListTile(
            title: BullText(
              context.loc.paySelectCoinsManually,
              style: context.bullType.body
                  .copyWith(fontWeight: FontWeight.w500)
                  .copyWith(fontWeight: .w500),
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              BullBottomSheet.show(
                context: context,
                child: BlocProvider.value(
                  value: context.read<PayBloc>(),
                  child: const PayCoinSelectionBottomSheet(),
                ),
              );
            },
          ),
          const Gap(24),
          BullButton.secondary(
            label: context.loc.payDone,
            onPressed: context.pop,
          ),
        ],
      ),
    );
  }
}
