import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/dca/ui/widgets/dca_amount_input_fields.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class DcaScreen extends StatefulWidget {
  const DcaScreen({super.key});

  @override
  State<DcaScreen> createState() => _DcaScreenState();
}

class _DcaScreenState extends State<DcaScreen> {
  final TextEditingController _amountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set recurring buy')),
      body: SafeArea(
        child: ScrollableColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Bitcoin purchases will be placed automatically per this schedule.',
                style: context.theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const Gap(24),
            DcaAmountInputFields(amountController: _amountController),
          ],
        ),
      ),
    );
  }
}
