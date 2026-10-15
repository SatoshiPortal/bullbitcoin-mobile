import 'package:bull_ui/bull_ui.dart';

class ProgressScreen extends StatelessWidget {
  final String? title;
  final String? description;
  final bool isLoading;
  const ProgressScreen({
    required this.isLoading,
    super.key,
    this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) => BullProgressScreen(
    isLoading: isLoading,
    title: title,
    description: description,
  );
}
