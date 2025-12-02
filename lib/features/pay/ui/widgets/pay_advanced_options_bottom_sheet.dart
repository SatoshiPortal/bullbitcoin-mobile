import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_coin_selection_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
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
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: BBText(
                  context.loc.payAdvancedOptions,
                  style: context.font.headlineMedium,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BBText(
                context.loc.payRbfActivated,
                style: context.font.headlineMedium,
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
            title: BBText(
              context.loc.paySelectCoinsManually,
              style: context.font.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: context.colorScheme.secondaryFixed,
                constraints: const BoxConstraints(maxWidth: double.infinity),
                useSafeArea: true,
                builder:
                    (BuildContext buildContext) => BlocProvider.value(
                      value: context.read<PayBloc>(),
                      child: const PayCoinSelectionBottomSheet(),
                    ),
              );
            },
          ),
          const Gap(24),
          BBButton.big(
            label: context.loc.payDone,
            onPressed: context.pop,
            bgColor: context.colorScheme.secondary,
            textColor: context.colorScheme.onSecondary,
          ),
        ],
      ),
    );
  }
}
