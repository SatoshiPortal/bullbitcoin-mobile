// import 'package:bb_mobile/_ui/app_bar.dart';
// import 'package:bb_mobile/home/bloc/home_cubit.dart';
// import 'package:bb_mobile/network/bloc/network_cubit.dart';
// import 'package:bb_mobile/swap/ui_swapwidget/swap_widget.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:go_router/go_router.dart';

// class Testground extends StatelessWidget {
//   const Testground({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final network = context.select((NetworkCubit x) => x.state.getBBNetwork());

//     final walletBlocs = context.select(
//       (HomeBloc x) => x.state.walletBlocsFromNetwork(network),
//     );

//     final wallets = walletBlocs.map((e) => e.state.wallet!).toList();

//     return Scaffold(
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         flexibleSpace: BBAppBar(
//           text: 'Swap',
//           onBack: () {
//             context.pop();
//           },
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(32.0),
//         child: SwapWidget(wallets: wallets),
//       ),
//     );
//   }
// }
