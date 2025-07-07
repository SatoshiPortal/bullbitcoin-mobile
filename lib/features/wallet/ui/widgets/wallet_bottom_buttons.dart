import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/send/ui/send_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WalletBottomButtons extends StatelessWidget {
  const WalletBottomButtons({super.key, this.wallet});

  final Wallet? wallet;

  @override
  Widget build(BuildContext context) {
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
    );

    return Row(
      // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: BBButton.big(
            iconData: Icons.arrow_downward,
            label: 'Receive',
            iconFirst: true,
            onPressed: () {
              // Lightning is the default receive method if no specific wallet is selected
              if (wallet == null) {
                context.pushNamed(ReceiveRoute.receiveLightning.name);
              } else {
                context.pushNamed(
                  wallet!.isLiquid
                      ? ReceiveRoute.receiveLiquid.name
                      : ReceiveRoute.receiveBitcoin.name,
                  extra: wallet,
                );
              }
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onPrimary,
          ),
        ),
        const Gap(4),
        Expanded(
          child: BBButton.big(
            iconData: Icons.crop_free,
            label: 'Send',
            iconFirst: true,
            onPressed:
                () => context.pushNamed(
                  SendRoute.requestIdentifier.name,
                  extra: wallet,
                ),
            bgColor: context.colour.secondary,
            textColor: context.colour.onPrimary,
            disabled: wallet?.signer == SignerEntity.none && !isSuperuser,
          ),
        ),
      ],
    );
  }
}

// import 'package:bb_mobile/router.dart';
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';

// class HomeBottomButtons extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Align(
//       alignment: Alignment.bottomCenter,
//       child: SizedBox(
//         height: 128,
//         child: Stack(
//           alignment: Alignment.center,
//           children: [
//             Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       child: ElevatedButton(
//                         onPressed: () =>
//                             context.pushNamed(AppRoute.receiveBitcoin.name),
//                         child: const Text('Receive'),
//                       ),
//                     ),
//                     const Expanded(
//                       child: ElevatedButton(
//                         onPressed: null,
//                         child: Text('Send'),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const Row(
//                   children: [
//                     Expanded(
//                       child:
//                           ElevatedButton(onPressed: null, child: Text('Buy')),
//                     ),
//                     Expanded(
//                       child:
//                           ElevatedButton(onPressed: null, child: Text('Sell')),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//             const ElevatedButton(
//               onPressed: null,
//               child: Icon(Icons.qr_code_scanner),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
