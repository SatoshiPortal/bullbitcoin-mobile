import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/payjoin/cubit.dart';
import 'package:bb_mobile/payjoin/state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PayjoinPage extends StatelessWidget {
  const PayjoinPage({super.key, required this.walletBloc});

  final WalletBloc walletBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PayjoinCubit>(
      create: (_) => PayjoinCubit(),
      child: Scaffold(
        backgroundColor: Colors.amber,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: BBAppBar(text: 'Payjoin', onBack: () => context.pop()),
        ),
        body: BlocListener<PayjoinCubit, PayjoinState>(
          listener: (context, state) {
            if (state.toast.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.toast),
                  backgroundColor: Colors.amber,
                ),
              );
              context.read<PayjoinCubit>().clearToast();
            }
          },
          child: BlocBuilder<PayjoinCubit, PayjoinState>(
            builder: (context, state) {
              final cubit = context.read<PayjoinCubit>();

              if (state.isReceiver) {
                return Form(
                  key: cubit.form,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              controller: cubit.address,
                              decoration: const InputDecoration(
                                labelText: 'address',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              controller: cubit.amount,
                              decoration: const InputDecoration(
                                labelText: 'amount',
                              ),
                              validator: cubit.validateAmount,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      BBButton.big(
                        loading: state.isAwaiting,
                        onPressed: cubit.clickCreateInvoice,
                        label: 'invoice',
                      ),
                      if (state.payjoinUri.isNotEmpty)
                        SelectableText(state.payjoinUri),
                    ],
                  ),
                );
              } else {
                return const Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
