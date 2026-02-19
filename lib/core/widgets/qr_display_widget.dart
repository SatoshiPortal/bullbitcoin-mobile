import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrDisplayWidget extends StatelessWidget {
  const QrDisplayWidget({super.key, required this.data, this.size = 300});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return LoadingBoxContent(height: size, width: size);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(maxHeight: size, maxWidth: size),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: QrImageView(data: data),
    );
  }
}
