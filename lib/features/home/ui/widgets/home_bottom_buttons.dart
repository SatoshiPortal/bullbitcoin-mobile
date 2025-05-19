import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/send/ui/send_router.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HomeBottomButtons extends StatelessWidget {
  const HomeBottomButtons({super.key, this.wallet});

  final Wallet? wallet;

  @override
  Widget build(BuildContext context) {
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
                context.push(ReceiveRoute.receiveLightning.path);
              } else {
                context.push(
                  wallet!.isLiquid
                      ? ReceiveRoute.receiveLiquid.path
                      : ReceiveRoute.receiveBitcoin.path,
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
            onPressed: () {
              context.push(SendRoute.send.path, extra: wallet);
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onPrimary,
            disabled:
                wallet?.source == WalletSource.xpub ||
                wallet?.source == WalletSource.coldcard,
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
