import 'package:bb_mobile/ui/components/template/screen_template.dart';
import 'package:flutter/material.dart';

class PageLayout extends StatelessWidget {
  const PageLayout({
    required this.bottomChild,
    required this.children,
    this.bottomHeight,
  });

  final Widget bottomChild;
  final List<Widget> children;
  final double? bottomHeight;

  @override
  Widget build(BuildContext context) {
    return StackedPage(
      bottomChildHeight:
          bottomHeight ?? MediaQuery.of(context).size.height * 0.11,
      bottomChild: bottomChild,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
