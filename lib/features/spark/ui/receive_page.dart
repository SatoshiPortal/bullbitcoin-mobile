import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/features/spark/presentation/cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceivePage extends StatelessWidget {
  const ReceivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SparkCubit>().state;
    final sparkAddress = state.receiveAddress;

    return Scaffold(
      appBar: AppBar(
        title: Text('Spark Receive', style: context.font.headlineMedium),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(16),
            ReceiveQR(qrData: sparkAddress),
            const Gap(16),
            SparkCopyAddressSection(sparkAddress: sparkAddress),
            const Gap(40),
          ],
        ),
      ),
    );
  }
}

class ReceiveQR extends StatelessWidget {
  const ReceiveQR({super.key, required this.qrData});
  final String qrData;

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}

class SparkCopyAddressSection extends StatefulWidget {
  const SparkCopyAddressSection({
    super.key,
    required this.sparkAddress,
  });

  final String sparkAddress;

  @override
  State<SparkCopyAddressSection> createState() =>
      _SparkCopyAddressSectionState();
}

class _SparkCopyAddressSectionState extends State<SparkCopyAddressSection> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Spark Address',
            style: context.font.titleMedium,
          ),
          const Gap(8),
          Text(
            'Share this Spark address to receive instant, low-fee payments.',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.outline,
            ),
          ),
          const Gap(16),
          CopyInput(
            text: widget.sparkAddress,
          ),
        ],
      ),
    );
  }
}
