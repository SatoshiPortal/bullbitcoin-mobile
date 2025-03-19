import 'package:bb_mobile/_ui/components/buttons/button.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HomeBottomButtons extends StatelessWidget {
  const HomeBottomButtons({super.key});

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
              context.pushNamed(AppRoute.receiveBitcoin.name);
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
              context.pushNamed(AppRoute.send.name);
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onPrimary,
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
