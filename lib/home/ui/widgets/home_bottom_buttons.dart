import 'package:flutter/material.dart';

class HomeBottomButtons extends StatelessWidget {
  const HomeBottomButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
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