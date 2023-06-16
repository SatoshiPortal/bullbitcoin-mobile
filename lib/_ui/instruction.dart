import 'package:bb_mobile/_ui/components/text.dart';
import 'package:flutter/material.dart';

ExpansionPanel createPanel({
  bool isExpanded = false,
  required String headerText,
  required Widget body,
}) {
  return ExpansionPanel(
    headerBuilder: (BuildContext context, bool isExpanded) {
      return ListTile(
        title: BBText.body(
          headerText,
        ),
      );
    },
    body: body,
    isExpanded: isExpanded,
  );
}

class StepTitle extends StatelessWidget {
  const StepTitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return BBText.body(
      text,
    );
  }
}
