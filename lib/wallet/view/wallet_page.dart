import 'package:bb_arch/_pkg/tx/tx_repository.dart';
import 'package:bb_arch/tx/bloc/tx_bloc.dart';
import 'package:bb_arch/wallet/cubit/wallet_page_cubit.dart';
import 'package:bb_arch/wallet/view/wallet_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final txRepository = context.read<TxRepository>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => WalletPageCubit()),
        BlocProvider(create: (_) => TxBloc(txRepository: txRepository))
      ],
      child: const WalletView(),
    );
  }
}