import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
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
  String _selectedOption = 'Ark';

  @override
  Widget build(BuildContext context) {
    final wallet = context.read<ArkCubit>().wallet;

    final btcAddress = wallet.boardingAddress;
    final arkAddress = wallet.offchainAddress;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ark Receive', style: context.font.headlineMedium),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BBSegmentFull(
                items: const {'Ark', 'Bitcoin'},
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
              qrData: _selectedOption == 'Bitcoin' ? btcAddress : arkAddress,
            ),
            const Gap(16),
            ArkCopyAddressSection(
              btcAddress: btcAddress,
              arkAddress: arkAddress,
              selectedOption: _selectedOption,
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
        widget.selectedOption == 'Bitcoin'
            ? widget.btcAddress
            : widget.arkAddress;
    final addressLabel =
        widget.selectedOption == 'Bitcoin'
            ? 'BTC Borading Address'
            : 'Ark Address';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(addressLabel, style: context.font.bodyMedium),
          const Gap(6),
          CopyInput(
            text: currentAddress,
            clipboardText: currentAddress,
            overflow: TextOverflow.ellipsis,
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
