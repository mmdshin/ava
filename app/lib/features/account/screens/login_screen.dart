import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:ava_web/common/widgets/app_card.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/data/api_client.dart';
import 'package:ava_web/features/about/about_info.dart';
import 'package:ava_web/features/account/session.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _register = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authProvider.notifier);
    try {
      if (_register) {
        await auth.register(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
      } else {
        await auth.login(_email.text, _password.text);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/images/mums_logo.png',
                            width: 88,
                            semanticLabel: 'آوا',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          AboutInfo.appName,
                          textAlign: TextAlign.center,
                          style: context.text.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _register
                              ? 'برای ذخیره پیشرفت و یادداشت‌هایتان حساب بسازید.'
                              : 'برای ادامه وارد حساب خود شوید.',
                          textAlign: TextAlign.center,
                          style: context.text.bodyMedium.copyWith(
                            color: context.onBgMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_register) ...[
                                TextFormField(
                                  controller: _name,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.name],
                                  decoration: const InputDecoration(
                                    labelText: 'نام (اختیاری)',
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              TextFormField(
                                key: const ValueKey('email'),
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textDirection: TextDirection.ltr,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: 'ایمیل',
                                  prefixIcon: Icon(
                                    Icons.alternate_email_rounded,
                                  ),
                                ),
                                validator: (v) =>
                                    v != null &&
                                        RegExp(
                                          r'^\S+@\S+\.\S+$',
                                        ).hasMatch(v.trim())
                                    ? null
                                    : 'ایمیل معتبر وارد کنید',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                key: const ValueKey('password'),
                                controller: _password,
                                obscureText: !_showPassword,
                                textDirection: TextDirection.ltr,
                                textInputAction: TextInputAction.done,
                                autofillHints: [
                                  _register
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'رمز عبور',
                                  helperText: _register
                                      ? 'حداقل 8 نویسه'
                                      : null,
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: _showPassword
                                        ? 'پنهان کردن رمز'
                                        : 'نمایش رمز',
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                    ),
                                    onPressed: () => setState(
                                      () => _showPassword = !_showPassword,
                                    ),
                                  ),
                                ),
                                validator: (v) =>
                                    (v ?? '').length < (_register ? 8 : 1)
                                    ? (_register
                                          ? 'رمز عبور باید حداقل 8 نویسه باشد'
                                          : 'رمز عبور را وارد کنید')
                                    : null,
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: AppSpacing.md),
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _error!,
                                    style: context.text.bodyMedium.copyWith(
                                      color: colors.danger,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(_register ? 'ساخت حساب' : 'ورود'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _register = !_register;
                                  _error = null;
                                }),
                          child: Text(
                            _register
                                ? 'حساب دارید؟ وارد شوید'
                                : 'حساب ندارید؟ ثبت‌نام کنید',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
