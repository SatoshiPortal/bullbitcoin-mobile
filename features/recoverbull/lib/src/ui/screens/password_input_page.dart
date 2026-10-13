import '../../presentation/bloc.dart';
import './fetch_vault_key_page.dart';
import './vault_provider_selection_page.dart';
import '../widgets/key_server_status_widget.dart';
import '../../utils/password_validator.dart';
import '../../router/flow_type.dart';
import '../../l10n/context_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_privacy/screen_privacy.dart';

enum InputType { pin, password, vaultKey }

class PasswordInputPage extends StatefulWidget {
  const PasswordInputPage({super.key});

  @override
  State<PasswordInputPage> createState() => _PasswordInputPageState();
}

/// The password, PIN or vault key typed here can be revealed, so screen
/// capture stays blocked while the page is mounted.
class _PasswordInputPageState extends State<PasswordInputPage>
    with PrivacyScreen {
  bool isObscured = true;
  InputType inputType = InputType.pin;
  String validatedPassword = '';
  final inputController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    enableScreenPrivacy();
  }

  @override
  void dispose() {
    disableScreenPrivacy();
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
      borderSide: BorderSide(color: context.bull.border),
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
          RecoverBullFlow.settings => throw UnimplementedError(),
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
          RecoverBullFlow.settings => throw UnimplementedError(),
        };

        return BullScaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            flexibleSpace: BullTopBar(
              onBack: () => context.pop(),
              title: title,
            ),
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
                crossAxisAlignment: .stretch,
                children: [
                  SizedBox(
                    height: 50,
                    child: Center(
                      child: BullText(
                        description,
                        textAlign: .center,
                        style: context.bullText.labelMedium?.copyWith(
                          color: context.bull.textMuted,
                        ),
                        maxLines: 3,
                      ),
                    ),
                  ),
                  const Gap(12),
                  BullText(
                    needPasswordConfirmation && validatedPassword.isNotEmpty
                        ? context.loc.recoverbullConfirmInput(inputTypeString)
                        : inputTypeString,
                    textAlign: .start,
                    style: context.bullText.labelSmall?.copyWith(
                      color: context.bull.textMuted,
                    ),
                  ),
                  const Gap(2),
                  TextFormField(
                    controller: inputController,
                    obscureText: isObscured,
                    readOnly: inputType == InputType.pin,
                    textAlign: .left,
                    textAlignVertical: TextAlignVertical.center,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    style: context.bullText.headlineSmall?.copyWith(
                      color: context.bull.onSurface,
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
                        icon: isObscured
                            ? const Icon(Icons.visibility_outlined)
                            : const Icon(Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => isObscured = !isObscured),
                      ),
                      border: borderDecoration,
                      enabledBorder: borderDecoration,
                      focusedBorder: borderDecoration,
                      disabledBorder: borderDecoration,
                      contentPadding: const EdgeInsets.all(16),
                      errorMaxLines: 4,
                    ),
                  ),
                  const Gap(16),
                  if (needPasswordConfirmation && validatedPassword.isNotEmpty)
                    BullButton.small(
                      label: context.loc.recoverbullGoBackEdit,
                      bgColor: context.bull.transparent,
                      textColor: context.bull.info,
                      textStyle: context.bullText.labelSmall,
                      onPressed: () {
                        setState(() {
                          validatedPassword = '';
                          inputController.clear();
                        });
                      },
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: BullButton.big(
                            label: inputType == InputType.pin
                                ? context.loc.recoverbullSwitchToPassword
                                : context.loc.recoverbullSwitchToPIN,
                            bgColor: context.bull.transparent,
                            textColor: context.bull.info,
                            textStyle: context.bullText.labelSmall,
                            onPressed: () {
                              inputType = inputType == InputType.pin
                                  ? InputType.password
                                  : InputType.pin;
                              inputController.clear();
                              validatedPassword = '';
                              isObscured = true;
                              setState(() {});
                            },
                          ),
                        ),
                        if (inputType != InputType.vaultKey && hasVaultKeyInput)
                          Expanded(
                            child: BullButton.small(
                              label:
                                  context.loc.recoverbullEnterVaultKeyInstead,
                              bgColor: context.bull.transparent,
                              textColor: context.bull.info,
                              textStyle: context.bullText.labelSmall,
                              onPressed: () {
                                inputType = InputType.vaultKey;
                                inputController.clear();
                                validatedPassword = '';
                                isObscured = true;
                                setState(() {});
                              },
                            ),
                          ),
                      ],
                    ),
                  const Spacer(),
                  if (inputType == InputType.pin)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: BullDialPad(
                        disableFeedback: true,
                        onlyDigits: true,
                        onNumberPressed: (e) => inputController.text += e,
                        onBackspacePressed: () {
                          if (inputController.text.isNotEmpty) {
                            inputController.text = inputController.text
                                .substring(0, inputController.text.length - 1);
                          }
                        },
                      ),
                    ),
                  if (inputType == InputType.pin) const Gap(12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 60),
                    child: BullButton.big(
                      label:
                          needPasswordConfirmation &&
                              validatedPassword.isNotEmpty
                          ? context.loc.recoverbullConfirm
                          : context.loc.recoverbullContinue,
                      textStyle: context.bullText.headlineLarge,
                      bgColor: context.bull.onSurface,
                      textColor: context.bull.surface,
                      disabled: state.isLoading,
                      onPressed: () {
                        if (context
                            .read<RecoverBullBloc>()
                            .hasPendingProviderSave) {
                          BullSnackBar.show(
                            context,
                            message: context.loc.recoverbullProviderSaveFailed,
                          );
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const VaultProviderSelectionPage(),
                            ),
                          );
                          return;
                        }
                        if (_formKey.currentState?.validate() ?? false) {
                          switch (state.flow) {
                            case RecoverBullFlow.secureVault:
                              if (validatedPassword.isEmpty) {
                                setState(() {
                                  validatedPassword = inputController.text;
                                  inputController.clear();
                                  isObscured = true;
                                });
                              } else {
                                context.read<RecoverBullBloc>().add(
                                  OnVaultPasswordSet(
                                    password: validatedPassword,
                                  ),
                                );
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const VaultProviderSelectionPage(),
                                  ),
                                );
                              }
                            default:
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => FetchVaultKeyPage(
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
