import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/admin/data/models.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/widgets/common.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/features/account/session.dart';

const _roleHelp = {
  'nurse': 'فقط از برنامه استفاده می‌کند',
  'editor': 'ویرایش پیش‌نویس',
  'reviewer': 'ویرایش و انتشار',
  'admin': 'همه کارها، کاربران و تنظیمات',
};

Color _roleColor(BuildContext context, String role) {
  final c = context.appColors;
  return switch (role) {
    'admin' => c.danger,
    'reviewer' => c.warning,
    'editor' => c.accent,
    _ => context.onBgMuted,
  };
}

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _query = '';
  String _role = '';

  Future<void> _create() async {
    final body = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _NewUserDialog(),
    );
    if (body == null || !mounted) return;
    await runAction(context, () async {
      await ref
          .read(adminApiProvider)
          .createUser(
            email: body['email']!,
            displayName: body['displayName']!,
            role: body['role']!,
            password: body['password']!,
          );
      ref.invalidate(usersProvider);
    }, success: 'حساب ساخته شد');
  }

  Future<void> _setRole(AdminUser u, String role) async {
    if (role == u.role) return;
    final ok = await confirm(
      context,
      title: 'تغییر نقش',
      message:
          'نقش ${u.displayName.isEmpty ? u.email : u.displayName} از «${roleLabels[u.role]}» به «${roleLabels[role]}» تغییر کند؟',
      action: 'تغییر نقش',
    );
    if (!ok || !mounted) return;
    await runAction(context, () async {
      await ref.read(adminApiProvider).setRole(u.email, role);
      ref.invalidate(usersProvider);
    }, success: 'نقش تغییر کرد');
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider);
    final all = users.value ?? const <AdminUser>[];
    final me = ref.watch(authProvider)?.user.email;
    return AdminPage(
      title: 'کاربران',
      subtitle: 'نقش هر حساب تعیین می‌کند چه کاری در پنل مدیریت می‌تواند بکند.',
      actions: [
        FilledButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('حساب جدید'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SearchField(
                hint: 'جستجوی نام یا ایمیل',
                onChanged: (v) => setState(() => _query = v),
              ),
              FilterPill(
                label: 'همه',
                count: all.length,
                selected: _role.isEmpty,
                onSelected: (_) => setState(() => _role = ''),
              ),
              for (final r in roleLabels.entries)
                FilterPill(
                  label: r.value,
                  count: all.where((u) => u.role == r.key).length,
                  color: _roleColor(context, r.key),
                  selected: _role == r.key,
                  onSelected: (_) => setState(() => _role = r.key),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AsyncBody(
            value: users,
            onRetry: () => ref.invalidate(usersProvider),
            builder: (list) {
              final q = _query.toLowerCase();
              final shown = [
                for (final u in list)
                  if ((_role.isEmpty || u.role == _role) &&
                      (q.isEmpty ||
                          u.email.toLowerCase().contains(q) ||
                          u.displayName.contains(_query)))
                    u,
              ];
              if (shown.isEmpty) {
                return const Panel(
                  child: EmptyState(
                    icon: Icons.person_search_rounded,
                    title: 'کاربری پیدا نشد',
                  ),
                );
              }
              return RowList(
                children: [
                  for (final u in shown)
                    ListRow(
                      key: ValueKey(u.id),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: _roleColor(
                          context,
                          u.role,
                        ).withValues(alpha: 0.15),
                        child: Text(
                          (u.displayName.isEmpty ? u.email : u.displayName)
                              .characters
                              .first
                              .toUpperCase(),
                          style: context.text.labelLarge.copyWith(
                            color: context.legible(_roleColor(context, u.role)),
                          ),
                        ),
                      ),
                      title: Wrap(
                        spacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(u.displayName.isEmpty ? u.email : u.displayName),
                          if (u.email == me) const Pill('شما'),
                        ],
                      ),
                      subtitle: Text(
                        [
                          u.email,
                          u.lastLoginAt == null
                              ? 'هنوز وارد نشده'
                              : 'آخرین ورود ${relativeTime(u.lastLoginAt)}',
                        ].join(' · '),
                      ),
                      trailing: [
                        if (u.email == me)
                          Pill(
                            roleLabels[u.role] ?? u.role,
                            color: _roleColor(context, u.role),
                          )
                        else
                          PopupMenuButton<String>(
                            tooltip: 'تغییر نقش',
                            onSelected: (r) => _setRole(u, r),
                            itemBuilder: (_) => [
                              for (final r in roleLabels.entries)
                                PopupMenuItem(
                                  value: r.key,
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      r.key == u.role
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                                      color: _roleColor(context, r.key),
                                    ),
                                    title: Text(r.value),
                                    subtitle: Text(_roleHelp[r.key] ?? ''),
                                  ),
                                ),
                            ],
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Pill(
                                  roleLabels[u.role] ?? u.role,
                                  color: _roleColor(context, u.role),
                                ),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: context.onBgMuted,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NewUserDialog extends StatefulWidget {
  const _NewUserDialog();

  @override
  State<_NewUserDialog> createState() => _NewUserDialogState();
}

class _NewUserDialogState extends State<_NewUserDialog> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  String _role = 'editor';
  bool _show = false;
  bool _tried = false;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  void _generate() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    setState(() {
      _password.text = [
        for (var i = 0; i < 14; i++) chars[r.nextInt(chars.length)],
      ].join();
      _show = true;
    });
  }

  String? get _emailError {
    final e = _email.text.trim();
    if (!_tried && e.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)
        ? null
        : 'ایمیل معتبر نیست';
  }

  String? get _passwordError {
    if (!_tried && _password.text.isEmpty) return null;
    return _password.text.length >= 8 ? null : 'حداقل 8 نویسه';
  }

  void _submit() {
    setState(() => _tried = true);
    if (_emailError != null || _passwordError != null) return;
    Navigator.pop(context, {
      'email': _email.text.trim(),
      'displayName': _name.text.trim(),
      'password': _password.text,
      'role': _role,
    });
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'حساب جدید',
      width: 460,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(onPressed: _submit, child: const Text('ساخت حساب')),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'نام'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _email,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'ایمیل',
              errorText: _emailError,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _password,
            textDirection: TextDirection.ltr,
            obscureText: !_show,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'رمز عبور اولیه',
              errorText: _passwordError,
              helperText:
                  'حداقل 8 نویسه؛ آن را به صاحب حساب بدهید تا پس از ورود عوضش کند.',
              helperMaxLines: 2,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _show ? 'پنهان کردن' : 'نمایش',
                    icon: Icon(
                      _show
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _show = !_show),
                  ),
                  IconButton(
                    tooltip: 'کپی',
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: _password.text.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(
                              ClipboardData(text: _password.text),
                            );
                            toast(context, 'رمز کپی شد');
                          },
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('ساخت رمز تصادفی'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('نقش', style: context.text.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          RadioGroup<String>(
            groupValue: _role,
            onChanged: (v) => setState(() => _role = v ?? _role),
            child: Column(
              children: [
                for (final r in roleLabels.entries)
                  RadioListTile<String>(
                    value: r.key,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.value),
                    subtitle: Text(_roleHelp[r.key] ?? ''),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
