import 'package:bb_mobile/_ui/components/navbar/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceiveSuccessScreen extends StatelessWidget {
  const ReceiveSuccessScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Receive',
          actionIcon: Icons.close,
          onAction: () {
            context.pop();
          },
        ),
      ),
      body: const SingleChildScrollView(
        child: SuccessPage(),
        // child: AmountPage(),
      ),
    );
  }
}

class SuccessPage extends StatelessWidget {
  const SuccessPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap(10),
        Text('TODO: Success Page'),
        Gap(40),
      ],
    );
  }
}
