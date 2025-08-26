import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/psbt_flow/show_bbqr/show_bbqr_widget.dart';
import 'package:bb_mobile/features/psbt_flow/show_psbt/coldcard_q_instructions_bottom_sheet.dart';
import 'package:bb_mobile/features/psbt_flow/show_psbt/show_psbt_cubit.dart';
import 'package:bb_mobile/features/psbt_flow/show_psbt/show_psbt_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ShowPsbtScreen extends StatelessWidget {
  final String psbt;
  final SignerDeviceEntity? signerDevice;

  const ShowPsbtScreen({super.key, required this.psbt, this.signerDevice});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShowPsbtCubit()..generateBbqr(psbt),
      child: Scaffold(
        appBar: AppBar(title: const Text('Sign transaction')),
        body: BlocBuilder<ShowPsbtCubit, ShowPsbtState>(
          builder: (context, state) {
            if (state.error != null) {
              return Center(
                child: Text(
                  state.error!,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.colour.error,
                  ),
                ),
              );
            }

            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      if (signerDevice != null &&
                          signerDevice == SignerDeviceEntity.coldcardQ) ...[
                        ShowBbqrWidget(parts: state.bbqrParts),
                        const Gap(16),
                      ],

                      if (signerDevice != null)
                        BBButton.small(
                          label: 'Instructions',
                          onPressed:
                              () => ColdcardQInstructionsBottomSheet.show(
                                context,
                              ),
                          bgColor: context.colour.onSecondary,
                          textColor: context.colour.secondary,
                          outlined: true,
                        ),
                    ],
                  ),

                  BBButton.big(
                    label: "I'm done",
                    bgColor: context.colour.secondary,
                    textColor: context.colour.onPrimary,
                    onPressed: () {
                      context.pushNamed(
                        BroadcastSignedTxRoute.broadcastHome.name,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
