import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceivePage extends StatelessWidget {
  const ReceivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ArkCubit, ArkState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!.message)));
        }
      },
      builder: (context, state) {
        final wallet = context.read<ArkCubit>().wallet;
        final cubit = context.read<ArkCubit>();

        String address = '';
        if (state.receiveMethod == ArkReceiveMethod.offchain) {
          address = wallet.offchainAddress;
        } else {
          address = wallet.boardingAddress;
        }

        return Scaffold(
          appBar: AppBar(
            title: BBText(
              'Ark Receive ${state.receiveMethod.name}',
              style: context.font.headlineMedium,
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Switch(
                  value: state.receiveMethod == ArkReceiveMethod.offchain,
                  onChanged: cubit.receiveMethodChanged,
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ReceiveQR(
                  qrData: address,
                  title: '${state.receiveMethod.name} address',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ReceiveQR extends StatelessWidget {
  const ReceiveQR({super.key, required this.qrData, required this.title});
  final String qrData;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 42),
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxHeight: 300, maxWidth: 300),
            decoration: BoxDecoration(
              color: context.colour.onPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                qrData.isNotEmpty
                    ? QrImageView(data: qrData)
                    : const LoadingBoxContent(height: 200),
          ),
        ),
        const Gap(20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BBText(title, style: context.font.bodyMedium),
              const Gap(6),
              CopyInput(
                text: qrData,
                clipboardText: qrData,
                overflow: TextOverflow.ellipsis,
                canShowValueModal: true,
                modalTitle: title,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ReceiveCopyAddress extends StatelessWidget {
  final String address;

  const ReceiveCopyAddress({super.key, required this.address});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16 + 12),
      child: Row(
        children: [
          BBText(
            'Copy or scan address only',
            style: context.font.headlineSmall,
          ),
        ],
      ),
    );
  }
}
