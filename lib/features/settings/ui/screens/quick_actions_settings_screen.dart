import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:flutter/widgets.dart';

class QuickActionsSettingsScreen extends StatelessWidget {
  const QuickActionsSettingsScreen({required this.cubit, super.key});
  final QuickActionsCubit cubit;

  @override
  Widget build(BuildContext context) =>
      QuickActionsCustomizationScreen(cubit: cubit);
}
