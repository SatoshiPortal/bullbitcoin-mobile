import 'package:bb_mobile/features/pos/domain/value_objects/pos_sale.dart';
import 'package:flutter/material.dart';

class PosSaleCard extends StatelessWidget {
  const PosSaleCard({super.key, required this.sale});

  final PosSale sale;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.receipt_long),
      title: Text('${sale.fiatAmount} ${sale.fiatCurrency}'),
      subtitle: Text('${sale.satAmount} sats • ${sale.status}'),
      trailing: sale.method == null ? null : Text(sale.method!),
    );
  }
}
