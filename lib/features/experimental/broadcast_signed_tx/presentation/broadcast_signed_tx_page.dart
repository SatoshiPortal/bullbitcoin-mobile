import 'package:bb_mobile/features/experimental/broadcast_signed_tx/broadcast_signed_tx_router.dart';
import 'package:bb_mobile/features/experimental/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/experimental/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/inputs/paste_input.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BroadcastSignedTxPage extends StatelessWidget {
  const BroadcastSignedTxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Broadcast Signed Transaction',
          onBack: () => context.pop(),
        ),
      ),
      body: BlocBuilder<BroadcastSignedTxCubit, BroadcastSignedTxState>(
        builder: (context, state) {
          final cubit = context.read<BroadcastSignedTxCubit>();

          return Column(
            children: [
              PasteInput(
                text: state.transaction?.data ?? '',
                hint: 'Paste a PSBT or transaction HEX',
                onChanged: cubit.tryParseTransaction,
              ),

              if (state.error != null)
                BBText(
                  state.error!,
                  style: context.font.bodyMedium,
                  color: context.colour.error,
                ),

              const Gap(32),
              Padding(
                padding: const EdgeInsets.only(left: 100, right: 100),
                child: BBButton.big(
                  label: 'Scan BBQR / Hex',
                  onPressed:
                      () => context.pushNamed(
                        BroadcastSignedTxRoute.broadcastScan.name,
                      ),
                  bgColor: context.colour.onPrimary,
                  textColor: context.colour.secondary,
                  iconData: Icons.qr_code_scanner,
                ),
              ),

              const Gap(32),

              // Broadcast button
              if (state.transaction != null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 100, right: 100),
                  child: BBButton.big(
                    label: 'Broadcast',
                    bgColor: context.colour.secondary,
                    textColor: context.colour.onPrimary,
                    onPressed: cubit.broadcastTransaction,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
