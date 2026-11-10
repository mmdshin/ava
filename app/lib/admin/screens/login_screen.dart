import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/widgets/common.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/data/api_client.dart';
import 'package:ava_web/features/account/session.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'ایمیل و رمز عبور را وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(_email.text, _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final session = ref.watch(authProvider);
    final role = ref.watch(roleProvider);
    final noAccess = session != null && !hasRole(role, 'editor');

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.brand,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'مدیریت محتوای آوا',
                  textAlign: TextAlign.center,
                  style: context.text.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'ویژه ویراستاران، بازبین‌ها و مدیران',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium.copyWith(
                    color: context.onBgMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Panel(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: noAccess
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              Icons.lock_person_rounded,
                              size: 40,
                              color: colors.warning,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'حساب ${session.user.email} به پنل مدیریت دسترسی ندارد. '
                              'از مدیر سامانه بخواهید نقش شما را تغییر دهد.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            OutlinedButton(
                              onPressed: () =>
                                  ref.read(authProvider.notifier).logout(),
                              child: const Text('خروج و ورود با حساب دیگر'),
                            ),
                          ],
                        )
                      : AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                key: const ValueKey('admin-email'),
                                controller: _email,
                                autofocus: true,
                                textDirection: TextDirection.ltr,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                onSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                                decoration: const InputDecoration(
                                  labelText: 'ایمیل',
                                  prefixIcon: Icon(
                                    Icons.alternate_email_rounded,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextField(
                                key: const ValueKey('admin-password'),
                                controller: _password,
                                focusNode: _passwordFocus,
                                obscureText: !_showPassword,
                                textDirection: TextDirection.ltr,
                                autofillHints: const [AutofillHints.password],
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'رمز عبور',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: _showPassword
                                        ? 'پنهان کردن رمز'
                                        : 'نمایش رمز',
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _showPassword = !_showPassword,
                                    ),
                                  ),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: AppSpacing.md),
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: colors.danger.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm - 4,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        size: 18,
                                        color: context.legible(colors.danger),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: context.text.bodySmall
                                              .copyWith(
                                                color: context.legible(
                                                  colors.danger,
                                                ),
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('ورود'),
                              ),
                            ],
                          ),
                        ),
                ),
                if (!noAccess) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'حساب ویرایش ندارید؟ از مدیر سامانه بخواهید نقش شما را تغییر دهد.',
                    textAlign: TextAlign.center,
                    style: context.text.labelMedium.copyWith(
                      color: context.onBgMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
