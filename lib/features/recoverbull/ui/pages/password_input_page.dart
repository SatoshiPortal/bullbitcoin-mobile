import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart' show BBText;
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/fetch_vault_key_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/vault_provider_selection_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/widgets/key_server_status_widget.dart';
import 'package:bb_mobile/features/recoverbull/utils/password_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

enum InputType {
  pin,
  password,
  vaultKey;

  String get name => switch (this) {
    InputType.pin => 'PIN',
    InputType.password => 'Password',
    InputType.vaultKey => 'Vault Key',
  };
}

class PasswordInputPage extends StatefulWidget {
  const PasswordInputPage({super.key});

  @override
  State<PasswordInputPage> createState() => _PasswordInputPageState();
}

class _PasswordInputPageState extends State<PasswordInputPage> {
  bool isObscured = false;
  InputType inputType = InputType.pin;
  String validatedPassword = '';
  final inputController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderDecoration = OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: BorderSide(color: context.colour.secondaryFixedDim),
    );

    return BlocBuilder<RecoverBullBloc, RecoverBullState>(
      builder: (context, state) {
        final needPasswordConfirmation =
            state.flow == RecoverBullFlow.secureVault;

        final hasVaultKeyInput = [
          RecoverBullFlow.testVault,
          RecoverBullFlow.recoverVault,
        ].contains(state.flow);

        final title = switch (state.flow) {
          RecoverBullFlow.secureVault => 'Secure your backup',
          RecoverBullFlow.recoverVault => 'Enter your ${inputType.name}',
          RecoverBullFlow.testVault => 'Enter your ${inputType.name}',
          RecoverBullFlow.viewVaultKey => 'Enter your ${inputType.name}',
        };

        final description = switch (state.flow) {
          RecoverBullFlow.secureVault =>
            needPasswordConfirmation && validatedPassword.isNotEmpty
                ? 'Please re-enter your ${inputType.name} to confirm.'
                : 'You must memorize this ${inputType.name} to recover access to your wallet. It must be at least 6 digits. If you lose this ${inputType.name} you cannot recover your backup.',
          RecoverBullFlow.recoverVault =>
            'Please enter your ${inputType.name} to decrypt your vault.',
          RecoverBullFlow.testVault =>
            'Please enter your ${inputType.name} to test your vault.',
          RecoverBullFlow.viewVaultKey =>
            'Please enter your ${inputType.name} to view your vault key.',
        };

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            flexibleSpace: TopBar(onBack: () => context.pop(), title: title),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 20),
                child: KeyServerStatusWidget(),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BBText(
                    description,
                    textAlign: TextAlign.center,
                    style: context.font.labelMedium?.copyWith(
                      color: context.colour.outline,
                    ),
                    maxLines: 3,
                  ),
                  const Gap(30),
                  BBText(
                    needPasswordConfirmation && validatedPassword.isNotEmpty
                        ? 'Confirm ${inputType.name}'
                        : inputType.name,
                    textAlign: TextAlign.start,
                    style: context.font.labelSmall?.copyWith(
                      color: context.colour.secondary,
                    ),
                  ),
                  const Gap(2),
                  TextFormField(
                    controller: inputController,
                    obscureText: isObscured,
                    readOnly: inputType == InputType.pin,
                    textAlign: TextAlign.left,
                    textAlignVertical: TextAlignVertical.center,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    style: context.font.headlineSmall?.copyWith(
                      color: context.colour.secondary,
                    ),
                    validator: (value) {
                      if (needPasswordConfirmation &&
                          validatedPassword.isNotEmpty) {
                        final error = PasswordValidator.validate(value);
                        if (error != null) return error;

                        return PasswordValidator.validateMatching(
                          value!,
                          validatedPassword,
                        );
                      } else {
                        return PasswordValidator.validate(value);
                      }
                    },
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        padding: const EdgeInsets.all(5),
                        icon:
                            isObscured
                                ? const Icon(Icons.visibility_outlined)
                                : const Icon(Icons.visibility_off_outlined),
                        onPressed:
                            () => setState(() => isObscured = !isObscured),
                      ),
                      border: borderDecoration,
                      enabledBorder: borderDecoration,
                      focusedBorder: borderDecoration,
                      disabledBorder: borderDecoration,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const Gap(30),
                  if (needPasswordConfirmation && validatedPassword.isNotEmpty)
                    BBButton.small(
                      label: '<< Go back and edit',
                      bgColor: Colors.transparent,
                      textColor: context.colour.inversePrimary,
                      textStyle: context.font.labelSmall,
                      onPressed: () {
                        setState(() {
                          validatedPassword = '';
                          inputController.clear();
                        });
                      },
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        BBButton.small(
                          label:
                              'Pick a ${inputType == InputType.pin ? 'password' : 'PIN'} instead',
                          bgColor: Colors.transparent,
                          textColor: context.colour.inversePrimary,
                          textStyle: context.font.labelSmall,
                          onPressed: () {
                            inputType =
                                inputType == InputType.pin
                                    ? InputType.password
                                    : InputType.pin;
                            inputController.clear();
                            validatedPassword = '';
                            setState(() {});
                          },
                        ),
                        if (inputType != InputType.vaultKey && hasVaultKeyInput)
                          BBButton.small(
                            label: 'Enter a vault key instead',
                            bgColor: Colors.transparent,
                            textColor: context.colour.inversePrimary,
                            textStyle: context.font.labelSmall,
                            onPressed: () {
                              inputType = InputType.vaultKey;
                              inputController.clear();
                              validatedPassword = '';
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                  if (inputType == InputType.pin)
                    DialPad(
                      disableFeedback: true,
                      onlyDigits: true,
                      onNumberPressed: (e) => inputController.text += e,
                      onBackspacePressed: () {
                        if (inputController.text.isNotEmpty) {
                          inputController.text = inputController.text.substring(
                            0,
                            inputController.text.length - 1,
                          );
                        }
                      },
                    ),
                  const Spacer(),

                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).size.height * 0.05,
                    ),
                    child: BBButton.big(
                      label:
                          needPasswordConfirmation &&
                                  validatedPassword.isNotEmpty
                              ? 'Confirm'
                              : 'Continue',
                      textStyle: context.font.headlineLarge,
                      bgColor: context.colour.secondary,
                      textColor: context.colour.onSecondary,
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          switch (state.flow) {
                            case RecoverBullFlow.secureVault:
                              if (validatedPassword.isEmpty) {
                                setState(() {
                                  validatedPassword = inputController.text;
                                  inputController.clear();
                                  isObscured = false;
                                });
                              } else {
                                context.read<RecoverBullBloc>().add(
                                  OnVaultPasswordSet(
                                    password: validatedPassword,
                                  ),
                                );
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            const VaultProviderSelectionPage(),
                                  ),
                                );
                              }
                            default:
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => FetchVaultKeyPage(
                                        input: inputController.text,
                                        inputType: inputType,
                                      ),
                                ),
                              );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
