import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/swap/swap_page_progress.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SendingOnChainTxPage extends StatefulWidget {
  const SendingOnChainTxPage({super.key});

  @override
  State<SendingOnChainTxPage> createState() => _SendingOnChainTxPageState();
}

class _SendingOnChainTxPageState extends State<SendingOnChainTxPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: BBAppBar(
          text: 'Swap in progress',
          onBack: () {
            context.pop();
          },
        ),
        automaticallyImplyLeading: false,
      ),
      body: const SendingOnChainTx(),
    );
  }
}
