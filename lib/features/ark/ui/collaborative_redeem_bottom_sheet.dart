import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class CollaborativeRedeemBottomSheet extends StatelessWidget {
  const CollaborativeRedeemBottomSheet({
    super.key,
    required this.cubit,
    required this.amount,
  });

  final ArkCubit cubit;
  final int amount;

  static Future<void> show(BuildContext context, ArkCubit cubit, int amount) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => CollaborativeRedeemBottomSheet(cubit: cubit, amount: amount),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: BlocBuilder<ArkCubit, ArkState>(
        bloc: cubit,
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    const Gap(20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Gap(24),
                        BBText(
                          'Collaborative Redeem',
                          style: context.font.headlineMedium,
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        value: state.withRecoverableVtxos,
                        onChanged: cubit.onChangedSelectRecoverableVtxos,
                        title: BBText(
                          'Recoverable Vtxos',
                          style: context.font.bodyMedium,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Gap(32),
                      Row(
                        children: [
                          Expanded(
                            child: BBButton.big(
                              label: 'Cancel',
                              onPressed: () => Navigator.of(context).pop(),
                              bgColor: context.colour.surface,
                              textColor: context.colour.onSurface,
                            ),
                          ),
                          const Gap(16),
                          Expanded(
                            child: BBButton.big(
                              label: 'Redeem',
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await cubit.onSendConfirmed();
                              },
                              bgColor: context.colour.primary,
                              textColor: context.colour.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
