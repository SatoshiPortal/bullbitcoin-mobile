import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:flutter/material.dart';

class FundExchangeCopBankTransferScreen extends StatelessWidget {
  const FundExchangeCopBankTransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.fundExchangeTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ScrollableColumn(
            mainAxisAlignment: .center,
            crossAxisAlignment: .start,
            children: [],
          ),
        ),
      ),
    );
  }
}
