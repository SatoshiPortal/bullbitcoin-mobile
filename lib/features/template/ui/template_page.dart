import 'package:bb_mobile/features/template/presentation/bloc/template_cubit.dart';
import 'package:bb_mobile/features/template/ui/template_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TemplatePage extends StatelessWidget {
  final String? initialData;
  final String? fromScreen;

  const TemplatePage({super.key, this.initialData, this.fromScreen});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Template Feature'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: BlocConsumer<TemplateCubit, TemplateState>(
        listener: (context, state) {
          if (state.hasError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<TemplateCubit>();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  onChanged: cubit.updateInputText,
                  decoration: const InputDecoration(
                    labelText: 'Enter text',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TemplateWidget(
                  title: 'Execute Operation',
                  subtitle: 'Perform template operation',
                  onTap:
                      state.canProceed ? cubit.executeTemplateOperation : null,
                  isLoading: state.isLoading,
                ),
                if (state.hasData) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Data:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(state.featureData.toString()),
                        ],
                      ),
                    ),
                  ),
                ],
                if (state.result.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Result:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(state.result),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                ElevatedButton(
                  onPressed: cubit.reset,
                  child: const Text('Reset'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
