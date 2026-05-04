import 'package:bb_mobile/features/pos/presentation/bloc/pos_cubit.dart';
import 'package:bb_mobile/features/pos/presentation/bloc/pos_sales_cubit.dart';
import 'package:bb_mobile/features/pos/presentation/widgets/pos_sale_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PosSalesScreen extends StatefulWidget {
  const PosSalesScreen({super.key});

  @override
  State<PosSalesScreen> createState() => _PosSalesScreenState();
}

class _PosSalesScreenState extends State<PosSalesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final identity = context.read<PosCubit>().state.identity;
      if (identity != null) context.read<PosSalesCubit>().start(identity.ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosSalesCubit, PosSalesState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('POS Sales'),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  final identity = context.read<PosCubit>().state.identity;
                  if (identity != null) {
                    context.read<PosSalesCubit>().refresh(identity.ref);
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.isLoading) const LinearProgressIndicator(),
              if (state.error != null)
                ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(state.error!),
                ),
              if (state.sales.isEmpty && !state.isLoading)
                const ListTile(
                  leading: Icon(Icons.receipt_long),
                  title: Text('No sales yet'),
                ),
              for (final sale in state.sales) PosSaleCard(sale: sale),
            ],
          ),
        );
      },
    );
  }
}
