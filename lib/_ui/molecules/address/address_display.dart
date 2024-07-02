import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AddressDisplay extends StatelessWidget {
  const AddressDisplay({
    super.key,
    required this.address,
  });

  final String address;

  void _onCopy(BuildContext context, String address) {
    BBClipboard.copy(address);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied address'),
      ),
    );
  }

  List<Widget> _buildQRAndCopyText(BuildContext context, String address) {
    if (address.isEmpty) {
      return const [
        Center(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No address specified'),
          ),
        ),
      ];
    }

    return [
      Center(
        child: QrImageView(
          data: address,
          size: 200.0,
        ),
      ),
      const SizedBox(
        height: 10,
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(address),
          const SizedBox(
            width: 10,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => _onCopy(context, address),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _buildQRAndCopyText(context, address),
    );
  }
}
