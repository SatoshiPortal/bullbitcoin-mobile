import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/nfc_scanner_widget.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ScanNfcPage extends StatelessWidget {
  const ScanNfcPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(title: 'NFC', onBack: () => context.pop()),
      ),
      body: BlocBuilder<BroadcastSignedTxCubit, BroadcastSignedTxState>(
        builder: (context, state) {
          final cubit = context.read<BroadcastSignedTxCubit>();
          return NfcScannerWidget(onScanned: cubit.onNfcScanned);
        },
      ),
    );
  }
}
