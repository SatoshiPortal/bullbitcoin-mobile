import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/presentation/cubit.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SelectCustomLocationPage extends StatefulWidget {
  const SelectCustomLocationPage({super.key});

  @override
  State<SelectCustomLocationPage> createState() =>
      _SelectCustomLocationPageState();
}

class _SelectCustomLocationPageState extends State<SelectCustomLocationPage> {
  @override
  void initState() {
    super.initState();
    // Trigger the custom location backup selection when the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context
          .read<RecoverBullSelectVaultCubit>()
          .selectCustomLocationBackup();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context
        .select<RecoverBullSelectVaultCubit, RecoverBullSelectVaultState>(
          (cubit) => cubit.state,
        );
    final error = state.error;

    final cubit = context.read<RecoverBullSelectVaultCubit>();

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () {
            cubit.clearState();
            context.pop();
          },
          title: "Custom Location",
        ),
      ),

      body: error != null ? Center(child: Text(error.message)) : null,
    );
  }
}
