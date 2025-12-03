import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/swap_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SwapExternalAddressInput extends StatelessWidget {
  const SwapExternalAddressInput({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context
        .select<TransferBloc, ({String address, String? error})>(
          (bloc) => (
            address: bloc.state.externalAddress,
            error: bloc.state.externalAddressError,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.loc.swapToLabel, style: context.font.bodyLarge),
        const Gap(4),
        BBInputText(
          onChanged: (value) {
            context.read<TransferBloc>().add(
              TransferEvent.externalAddressChanged(value),
            );
          },
          value: state.address,
          hint: context.loc.swapExternalAddressHint,
          hintStyle: context.font.bodyMedium?.copyWith(
            color: context.appColors.surfaceContainer,
          ),
          maxLines: 1,
          rightIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.qr_code_scanner,
                  color: context.appColors.secondary,
                  size: 20,
                ),
                onPressed: () async {
                  final result = await context.pushNamed<String>(
                    SwapRoute.scanQr.name,
                  );
                  if (result != null && context.mounted) {
                    context.read<TransferBloc>().add(
                      TransferEvent.externalAddressChanged(result),
                    );
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.paste_sharp,
                  color: context.appColors.secondary,
                  size: 20,
                ),
                onPressed: () {
                  Clipboard.getData(Clipboard.kTextPlain).then((value) {
                    if (value != null) {
                      if (context.mounted) {
                        context.read<TransferBloc>().add(
                          TransferEvent.externalAddressChanged(
                            value.text ?? '',
                          ),
                        );
                      }
                    }
                  });
                },
              ),
            ],
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: BBText(
              state.error!,
              style: context.font.labelSmall,
              color: context.appColors.error,
            ),
          ),
      ],
    );
  }
}
