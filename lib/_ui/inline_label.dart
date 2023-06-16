import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';

class InlineLabel extends StatelessWidget {
  const InlineLabel({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: '$title: ', style: context.font.labelSmall),
          TextSpan(
            text: body,
            style: context.font.bodySmall,
          ),
        ],
      ),
    );
  }
}
