import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/screens/transactions_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExchangeTransactionsScreen extends StatelessWidget {
  const ExchangeTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TransactionsCubit>(
      create: (context) => locator<TransactionsCubit>(param2: true)..loadTxs(),
      child: const TransactionsScreen(),
    );
  }
}
