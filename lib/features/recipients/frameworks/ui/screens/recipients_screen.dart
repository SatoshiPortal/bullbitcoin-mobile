import 'package:flutter/material.dart';

class RecipientsScreen extends StatelessWidget {
  const RecipientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recipients')),
      body: const Center(child: Text('Recipients Screen Content')),
    );
  }
}
