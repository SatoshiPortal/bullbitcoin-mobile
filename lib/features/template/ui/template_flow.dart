import 'package:bb_mobile/features/template/presentation/bloc/template_cubit.dart';
import 'package:bb_mobile/features/template/ui/template_page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TemplateFlow extends StatelessWidget {
  final String? initialData;
  final String? fromScreen;

  const TemplateFlow({super.key, this.initialData, this.fromScreen});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => locator<TemplateCubit>(),
      child: TemplatePage(initialData: initialData, fromScreen: fromScreen),
    );
  }
}
