import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core_deprecated/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core_deprecated/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  String? _selectedOption;

  @override
  Widget build(BuildContext context) {
    _selectedOption ??= context.loc.arkReceiveSegmentArk;
    final wallet = context.read<ArkCubit>().wallet;

    final btcAddress = wallet.boardingAddress;
    final arkAddress = wallet.offchainAddress;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.loc.arkReceiveTitle,
          style: context.font.headlineMedium,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            const Gap(16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BBSegmentFull(
                items: {
                  context.loc.arkReceiveSegmentArk,
                  context.loc.arkReceiveSegmentBoarding,
                },
                initialValue: _selectedOption,
                onSelected: (value) {
                  setState(() {
                    _selectedOption = value;
                  });
                },
              ),
            ),
            const Gap(16),
            ReceiveQR(
              qrData:
                  _selectedOption! == context.loc.arkReceiveSegmentBoarding
                      ? btcAddress
                      : arkAddress,
            ),
            const Gap(16),
            ArkCopyAddressSection(
              btcAddress: btcAddress,
              arkAddress: arkAddress,
              selectedOption: _selectedOption!,
            ),
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
          color: context.appColors.onPrimary,
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

class ArkCopyAddressSection extends StatefulWidget {
  const ArkCopyAddressSection({
    super.key,
    required this.btcAddress,
    required this.arkAddress,
    required this.selectedOption,
  });

  final String btcAddress;
  final String arkAddress;
  final String selectedOption;

  @override
  State<ArkCopyAddressSection> createState() => _ArkCopyAddressSectionState();
}

class _ArkCopyAddressSectionState extends State<ArkCopyAddressSection> {
  @override
  Widget build(BuildContext context) {
    final currentAddress =
        widget.selectedOption == context.loc.arkReceiveSegmentBoarding
            ? widget.btcAddress
            : widget.arkAddress;
    final addressLabel =
        widget.selectedOption == context.loc.arkReceiveSegmentBoarding
            ? context.loc.arkReceiveBoardingAddress
            : context.loc.arkArkAddress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Text(addressLabel, style: context.font.bodyMedium),
          const Gap(6),
          CopyInput(
            text: currentAddress,
            clipboardText: currentAddress,
            overflow: .ellipsis,
            canShowValueModal: true,
            modalTitle: addressLabel,
            modalContent:
                currentAddress
                    .replaceAllMapped(
                      RegExp('.{1,4}'),
                      (match) => '${match.group(0)} ',
                    )
                    .trim(),
          ),
        ],
      ),
    );
  }
}
