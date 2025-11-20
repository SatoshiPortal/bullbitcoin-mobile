import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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

enum InputType { pin, password, vaultKey }

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

  String _getInputTypeString(BuildContext context, InputType type) {
    return switch (type) {
      InputType.pin => context.loc.recoverbullPIN,
      InputType.password => context.loc.recoverbullPassword,
      InputType.vaultKey => context.loc.recoverbullVaultKeyInput,
    };
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

        final inputTypeString = _getInputTypeString(context, inputType);

        final title = switch (state.flow) {
          RecoverBullFlow.secureVault => context.loc.recoverbullSecureBackup,
          RecoverBullFlow.recoverVault => context.loc.recoverbullEnterInput(
            inputTypeString,
          ),
          RecoverBullFlow.testVault => context.loc.recoverbullEnterInput(
            inputTypeString,
          ),
          RecoverBullFlow.viewVaultKey => context.loc.recoverbullEnterInput(
            inputTypeString,
          ),
        };

        final description = switch (state.flow) {
          RecoverBullFlow.secureVault =>
            needPasswordConfirmation && validatedPassword.isNotEmpty
                ? context.loc.recoverbullReenterConfirm(inputTypeString)
                : context.loc.recoverbullMemorizeWarning(inputTypeString),
          RecoverBullFlow.recoverVault => context.loc.recoverbullEnterToDecrypt(
            inputTypeString,
          ),
          RecoverBullFlow.testVault => context.loc.recoverbullEnterToTest(
            inputTypeString,
          ),
          RecoverBullFlow.viewVaultKey => context.loc.recoverbullEnterToView(
            inputTypeString,
          ),
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
                  const Gap(16),
                  BBText(
                    needPasswordConfirmation && validatedPassword.isNotEmpty
                        ? context.loc.recoverbullConfirmInput(inputTypeString)
                        : inputTypeString,
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
                        if (value == null || value.isEmpty) {
                          return context.loc.recoverbullReenterRequired(
                            inputTypeString,
                          );
                        }

                        final error = PasswordValidator.validate(
                          value,
                          context,
                        );
                        if (error != null) return error;

                        return PasswordValidator.validateMatching(
                          value,
                          validatedPassword,
                          context,
                        );
                      } else {
                        return PasswordValidator.validate(value, context);
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
                      errorMaxLines: 4,
                    ),
                  ),
                  const Gap(30),
                  if (needPasswordConfirmation && validatedPassword.isNotEmpty)
                    BBButton.small(
                      label: context.loc.recoverbullGoBackEdit,
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
                              inputType == InputType.pin
                                  ? context.loc.recoverbullSwitchToPassword
                                  : context.loc.recoverbullSwitchToPIN,
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
                            label: context.loc.recoverbullEnterVaultKeyInstead,
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
                              ? context.loc.recoverbullConfirm
                              : context.loc.recoverbullContinue,
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
