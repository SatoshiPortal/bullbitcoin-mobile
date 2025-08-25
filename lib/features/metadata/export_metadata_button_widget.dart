import 'package:flutter/material.dart';

class ExportMetadataButtonWidget extends StatefulWidget {
  const ExportMetadataButtonWidget({super.key});

  @override
  State<ExportMetadataButtonWidget> createState() =>
      _ExportMetadataButtonWidgetState();
}

class _ExportMetadataButtonWidgetState
    extends State<ExportMetadataButtonWidget> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {},
      child: const Text('Export Metadata'),
    );
  }
}
