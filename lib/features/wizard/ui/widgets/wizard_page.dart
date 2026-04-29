import 'package:bb_mobile/core/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WizardPage extends StatelessWidget {
  const WizardPage({super.key, required this.image, required this.child});

  final String image;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final imageHeight = Device.screen.height * 0.20;
    final gap = Device.screen.height * 0.035;
    final pad = Device.screen.width * 0.06;
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SvgPicture.asset(
            image,
            height: imageHeight,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => SizedBox(height: imageHeight),
          ),
          SizedBox(height: gap),
          child,
        ],
      ),
    );
  }
}
