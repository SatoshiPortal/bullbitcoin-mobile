import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DevPageData {
  const DevPageData({
    required this.route,
    required this.title,
    this.done = false,
  });

  final String route;
  final String title;
  final bool done;
}

class DevPage extends StatelessWidget {
  const DevPage({
    super.key,
    required this.title,
    required this.pages,
  });

  final String title;
  final List<DevPageData> pages;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              for (final page in pages)
                BBButton.big(
                  label: page.title,
                  onPressed: () => context.pushNamed(page.route),
                  bgColor: page.done ? Colors.green : Colors.red,
                  textColor: Colors.white,
                  iconData: Icons.arrow_forward,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
