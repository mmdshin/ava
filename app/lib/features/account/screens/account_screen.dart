import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/common/messenger.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:ava_web/common/widgets/app_card.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/data/api_client.dart';
import 'package:ava_web/features/account/session.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  static const _roles = {
    'nurse': 'کاربر',
    'editor': 'ویراستار محتوا',
    'reviewer': 'بازبین محتوا',
    'admin': 'مدیر سامانه',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider)?.user;
    if (user == null) return const SizedBox.shrink();
    final colors = context.appColors;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FlowAppBar(
        title: Text('حساب کاربری', style: context.text.titleLarge),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: colors.accent.withValues(
                            alpha: 0.15,
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: colors.accent,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name, style: context.text.titleMedium),
                              Text(
                                user.email,
                                textDirection: TextDirection.ltr,
                                style: context.text.bodyMedium.copyWith(
                                  color: context.onBgMuted,
                                ),
                              ),
                              Text(
                                _roles[user.role] ?? user.role,
                                style: context.text.labelMedium.copyWith(
                                  color: colors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.password_rounded),
                          title: const Text('تغییر رمز عبور'),
                          subtitle: const Text(
                            'از دستگاه‌های دیگر خارج می‌شوید',
                          ),
                          onTap: () => _changePassword(context, ref),
                        ),
                        ListTile(
                          leading: const Icon(Icons.logout_rounded),
                          title: const Text('خروج از حساب'),
                          onTap: () => ref.read(authProvider.notifier).logout(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    accent: colors.danger,
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_forever_rounded,
                        color: colors.danger,
                      ),
                      title: Text(
                        'حذف حساب',
                        style: TextStyle(color: colors.danger),
                      ),
                      subtitle: const Text(
                        'حساب و همه نشان‌شده‌ها، یادداشت‌ها و نتایج آزمون برای همیشه پاک می‌شوند.',
                      ),
                      onTap: () => _deleteAccount(context, ref),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _PasswordDialog(
        title: 'تغییر رمز عبور',
        fields: const ['رمز فعلی', 'رمز جدید (حداقل 8 نویسه)'],
        action: 'ذخیره',
        onSubmit: (values) => ref
            .read(authProvider.notifier)
            .changePassword(values[0], values[1]),
      ),
    );
    if (changed == true) showAppMessage('رمز عبور تغییر کرد');
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => _PasswordDialog(
        title: 'حذف حساب',
        message: 'این کار برگشت‌پذیر نیست. برای تأیید، رمز عبور را وارد کنید.',
        fields: const ['رمز عبور'],
        action: 'حذف برای همیشه',
        destructive: true,
        onSubmit: (values) =>
            ref.read(authProvider.notifier).deleteAccount(values[0]),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({
    required this.title,
    required this.fields,
    required this.action,
    required this.onSubmit,
    this.message,
    this.destructive = false,
  });

  final String title;
  final String? message;
  final List<String> fields;
  final String action;
  final bool destructive;
  final Future<void> Function(List<String> values) onSubmit;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  late final _controllers = [
    for (final _ in widget.fields) TextEditingController(),
  ];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit([for (final c in _controllers) c.text]);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final danger = context.appColors.danger;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: AppSpacing.md),
          ],
          for (final (i, label) in widget.fields.indexed) ...[
            TextField(
              controller: _controllers[i],
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: label),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (_error != null) Text(_error!, style: TextStyle(color: danger)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('انصراف'),
        ),
        FilledButton(
          style: widget.destructive
              ? FilledButton.styleFrom(backgroundColor: danger)
              : null,
          onPressed: _busy ? null : _submit,
          child: Text(widget.action),
        ),
      ],
    );
  }
}
