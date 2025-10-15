import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bip21_uri/bip21_uri.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  String _generateBip21Uri(String btcAddress, String arkAddress) {
    final options = <String, dynamic>{'ark': arkAddress};

    final bip21UriObject = Bip21Uri(
      scheme: 'bitcoin',
      address: btcAddress,
      options: options,
    );
    return bip21UriObject.toString();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.read<ArkCubit>().wallet;

    final btcAddress = wallet.boardingAddress;
    final arkAddress = wallet.offchainAddress;
    final bip21UriString = _generateBip21Uri(btcAddress, arkAddress);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ark Receive', style: context.font.headlineMedium),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(16),
            ReceiveQR(qrData: bip21UriString),
            const Gap(16),
            ArkCopyAddressSection(
              bip21Uri: bip21UriString,
              btcAddress: btcAddress,
              arkAddress: arkAddress,
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
    required this.bip21Uri,
    required this.btcAddress,
    required this.arkAddress,
  });

  final String bip21Uri;
  final String btcAddress;
  final String arkAddress;

  @override
  State<ArkCopyAddressSection> createState() => _ArkCopyAddressSectionState();
}

class _ArkCopyAddressSectionState extends State<ArkCopyAddressSection> {
  bool _isExpanded = false;

  void _copyAndExpand() {
    Clipboard.setData(ClipboardData(text: widget.bip21Uri));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unified address copied'),
        duration: Duration(seconds: 2),
      ),
    );
    setState(() {
      _isExpanded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap:
                _isExpanded
                    ? () {
                      setState(() {
                        _isExpanded = false;
                      });
                    }
                    : _copyAndExpand,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: context.colour.surface),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Copy address', style: context.font.headlineSmall),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: context.colour.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Gap(8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colour.onPrimary,
                border: Border.all(color: context.colour.surface),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Unified address (BIP21)',
                    style: context.font.labelSmall?.copyWith(
                      color: context.colour.outline,
                    ),
                  ),
                  const Gap(6),
                  CopyInput(
                    text: widget.bip21Uri,
                    clipboardText: widget.bip21Uri,
                    overflow: TextOverflow.ellipsis,
                    canShowValueModal: true,
                    modalTitle: 'Unified address (BIP21)',
                  ),
                  const Gap(16),
                  Text(
                    'BTC address',
                    style: context.font.labelSmall?.copyWith(
                      color: context.colour.outline,
                    ),
                  ),
                  const Gap(6),
                  CopyInput(
                    text: widget.btcAddress,
                    clipboardText: widget.btcAddress,
                    overflow: TextOverflow.ellipsis,
                    canShowValueModal: true,
                    modalTitle: 'BTC address',
                    modalContent:
                        widget.btcAddress
                            .replaceAllMapped(
                              RegExp('.{1,4}'),
                              (match) => '${match.group(0)} ',
                            )
                            .trim(),
                  ),
                  const Gap(16),
                  Text(
                    'Ark address',
                    style: context.font.labelSmall?.copyWith(
                      color: context.colour.outline,
                    ),
                  ),
                  const Gap(6),
                  CopyInput(
                    text: widget.arkAddress,
                    clipboardText: widget.arkAddress,
                    overflow: TextOverflow.ellipsis,
                    canShowValueModal: true,
                    modalTitle: 'Ark address',
                    modalContent:
                        widget.arkAddress
                            .replaceAllMapped(
                              RegExp('.{1,4}'),
                              (match) => '${match.group(0)} ',
                            )
                            .trim(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
