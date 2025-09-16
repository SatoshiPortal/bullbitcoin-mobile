import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ArkPage extends StatelessWidget {
  const ArkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ark')),
      body: BlocBuilder<ArkCubit, ArkState>(
        builder: (context, state) {
          final cubit = context.read<ArkCubit>();

          return Column(
            children: [
              SelectableText(cubit.wallet.offchainAddress()),

              if (state.error != null) ...[
                Text(
                  state.error!.message,
                  style: TextStyle(color: context.colour.error),
                ),
                const Gap(16),
              ],
            ],
          );
        },
      ),
    );
  }
}
