import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:flutter/material.dart';

class ReceivePaymentReceivedDetails extends StatelessWidget {
  final ReceiveState receiveState;

  const ReceivePaymentReceivedDetails({
    super.key,
    required this.receiveState,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text('ReceivePaymentReceivedDetailsTable'),
    );
  }
}
