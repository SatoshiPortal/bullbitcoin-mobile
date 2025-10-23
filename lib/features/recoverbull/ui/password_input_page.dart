import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart' show BBText;
import 'package:bb_mobile/features/recoverbull/password_validator.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/fetch_vault_secret_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/select_vault_provider_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

enum InputType { pin, password }

class PasswordInputPage extends StatefulWidget {
  const PasswordInputPage({super.key});

  @override
  State<PasswordInputPage> createState() => _PasswordInputPageState();
}

class _PasswordInputPageState extends State<PasswordInputPage> {
  bool isObscured = false;
  InputType passwordType = InputType.pin;
  String validatedPassword = '';
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderDecoration = OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: BorderSide(color: context.colour.secondaryFixedDim),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: 'Secure your backup',
        ),
      ),
      body: BlocBuilder<RecoverBullBloc, RecoverBullState>(
        builder: (context, state) {
          final needPasswordConfirmation =
              state.flow == RecoverBullFlow.secureVault;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BBText(
                    needPasswordConfirmation && validatedPassword.isNotEmpty
                        ? 'Please re-enter your ${passwordType == InputType.pin ? 'PIN' : 'password'} to confirm.'
                        : 'You must memorize this password to recover access to your wallet. It must be at least 6 digits. If you lose this password you cannot recover your backup.',
                    textAlign: TextAlign.center,
                    style: context.font.labelMedium?.copyWith(
                      color: context.colour.outline,
                    ),
                    maxLines: 3,
                  ),
                  const Gap(30),
                  BBText(
                    needPasswordConfirmation && validatedPassword.isNotEmpty
                        ? 'Confirm ${passwordType == InputType.pin ? 'PIN' : 'Password'}'
                        : passwordType == InputType.pin
                        ? 'PIN'
                        : 'Password',
                    textAlign: TextAlign.start,
                    style: context.font.labelSmall?.copyWith(
                      color: context.colour.secondary,
                    ),
                  ),
                  const Gap(2),
                  TextFormField(
                    controller: passwordController,
                    obscureText: isObscured,
                    readOnly: passwordType == InputType.pin,
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
                          passwordController.clear();
                        });
                      },
                    )
                  else
                    BBButton.small(
                      label:
                          'Pick a ${passwordType == InputType.pin ? 'password' : 'PIN'} instead >>',
                      bgColor: Colors.transparent,
                      textColor: context.colour.inversePrimary,
                      textStyle: context.font.labelSmall,
                      onPressed: () {
                        passwordType =
                            passwordType == InputType.pin
                                ? InputType.password
                                : InputType.pin;
                        passwordController.clear();
                        validatedPassword = '';
                        setState(() {});
                      },
                    ),
                  if (passwordType == InputType.pin)
                    DialPad(
                      disableFeedback: true,
                      onlyDigits: true,
                      onNumberPressed: (e) => passwordController.text += e,
                      onBackspacePressed: () {
                        if (passwordController.text.isNotEmpty) {
                          passwordController.text = passwordController.text
                              .substring(0, passwordController.text.length - 1);
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
                                  validatedPassword = passwordController.text;
                                  passwordController.clear();
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
                                            const SelectVaultProviderPage(),
                                  ),
                                );
                              }
                            default:
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => const FetchVaultSecretPage(),
                                ),
                              );
                              context.read<RecoverBullBloc>().add(
                                OnVaultPasswordSet(
                                  password: passwordController.text,
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
          );
        },
      ),
    );
  }
}
