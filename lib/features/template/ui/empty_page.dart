import 'package:flutter/material.dart';

class EmptyPage extends StatelessWidget {
  final String someData;

  const EmptyPage({super.key, required this.someData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(someData)));
  }
}
