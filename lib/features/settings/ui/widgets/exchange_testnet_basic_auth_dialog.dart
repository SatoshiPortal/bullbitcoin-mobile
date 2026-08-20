import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> showExchangeTestnetBasicAuthDialog(BuildContext context) {
  final cubit = context.read<SettingsCubit>();
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const _ExchangeTestnetBasicAuthDialog(),
    ),
  );
}

class _ExchangeTestnetBasicAuthDialog extends StatefulWidget {
  const _ExchangeTestnetBasicAuthDialog();

  @override
  State<_ExchangeTestnetBasicAuthDialog> createState() =>
      _ExchangeTestnetBasicAuthDialogState();
}

class _ExchangeTestnetBasicAuthDialogState
    extends State<_ExchangeTestnetBasicAuthDialog> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    final state = context.read<SettingsCubit>().state;
    _usernameController = TextEditingController(
      text: state.exchangeTestnetBasicAuthUsername ?? '',
    );
    _passwordController = TextEditingController(
      text: state.exchangeTestnetBasicAuthPassword ?? '',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.loc.exchangeTestnetBasicAuthTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.loc.exchangeTestnetBasicAuthDescription),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: context.loc.exchangeTestnetBasicAuthUsernameLabel,
            ),
          ),
          TextField(
            controller: _passwordController,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: context.loc.exchangeTestnetBasicAuthPasswordLabel,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await context.read<SettingsCubit>().setExchangeTestnetBasicAuth();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(context.loc.exchangeTestnetBasicAuthClearButton),
        ),
        TextButton(
          onPressed: () async {
            await context.read<SettingsCubit>().setExchangeTestnetBasicAuth(
              username: _usernameController.text,
              password: _passwordController.text,
            );
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(context.loc.exchangeTestnetBasicAuthSaveButton),
        ),
      ],
    );
  }
}
