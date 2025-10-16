import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/swap/presentation/swap_bloc.dart';
import 'package:bb_mobile/features/swap/presentation/swap_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SwapPage extends StatefulWidget {
  const SwapPage({super.key});
  @override
  _SwapPageState createState() => _SwapPageState();
}

class _SwapPageState extends State<SwapPage> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Internal Transfer'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BlocSelector<SwapCubit, SwapState, bool>(
            selector: (state) => state.amountConfirmedClicked,
            builder:
                (context, amountConfirmedClicked) => FadingLinearProgress(
                  height: 3,
                  trigger: amountConfirmedClicked,
                  backgroundColor: context.colour.onPrimary,
                  foregroundColor: context.colour.primary,
                ),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ScrollableColumn(children: []),
          ),
        ),
      ),
    );
  }
}
