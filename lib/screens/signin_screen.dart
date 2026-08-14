import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_buttons.dart';
import 'admin_home_screen.dart';

/// Admin-only sign in. Deliberately separate from the public [LoginScreen]
/// — an account's admin status shouldn't be reachable through a generic,
/// guessable email/password form, so this is its own dedicated door,
/// linked only from the small "Admin portal" entry on the landing page.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = await _authService.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        role: UserRole.admin,
      );
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AdminHomeScreen(user: user)),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(UserRole.admin.signinHeadline, style: textTheme.displayLarge?.copyWith(fontSize: 28)),
                const SizedBox(height: 6),
                Text(UserRole.admin.signinSubtitle, style: textTheme.bodyLarge?.copyWith(color: AppColors.slate)),

                const SizedBox(height: AppSpacing.xl),

                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', hintText: 'you@example.com'),
                  validator: Validators.email,
                ),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => Validators.notEmpty(v, label: 'Password'),
                ),

                const SizedBox(height: AppSpacing.lg),

                PrimaryButton(label: 'Sign In', isLoading: _isLoading, onPressed: _submit),

                const SizedBox(height: AppSpacing.md),
                const Text(
                  "Checked against your real account — you'll need the email/password of an account that was signed up with the Admin role.",
                  style: TextStyle(fontSize: 12, color: AppColors.slate),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
