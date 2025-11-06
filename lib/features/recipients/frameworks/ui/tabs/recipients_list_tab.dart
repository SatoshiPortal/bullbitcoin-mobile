import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/jurisdiction_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class RecipientsListTab extends StatefulWidget {
  const RecipientsListTab({super.key});

  @override
  _RecipientsListTabState createState() => _RecipientsListTabState();
}

class _RecipientsListTabState extends State<RecipientsListTab> {
  String? _jurisdictionFilter;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        JurisdictionsDropdown(
          selectedJurisdiction: _jurisdictionFilter,
          includeAllOption: true,
          onChanged: (newJurisdiction) {
            if (newJurisdiction == null) return;
            setState(() {
              _jurisdictionFilter = newJurisdiction;
            });
          },
        ),
        const Gap(16.0),
      ],
    );
  }
}
