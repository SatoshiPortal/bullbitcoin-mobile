import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/nfc_scanner_widget.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart';

class ScanNfcPage extends StatelessWidget {
  const ScanNfcPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BullPage(
      topBar: BullTopBar(
        title: context.loc.broadcastSignedTxNfcTitle,
        onBack: () => context.pop(),
      ),
      padding: EdgeInsets.zero,
      child: BlocBuilder<BroadcastSignedTxCubit, BroadcastSignedTxState>(
        builder: (context, state) {
          final cubit = context.read<BroadcastSignedTxCubit>();
          return NfcScannerWidget(onScanned: cubit.onNfcScanned);
        },
      ),
    );
  }
}
