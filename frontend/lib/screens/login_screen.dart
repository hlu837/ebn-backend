import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_buttons.dart';
import 'role_router.dart';
import 'role_select_screen.dart';

/// The standard, single login page — plain email + password, no role
/// picker in sight. All the role logic happens after "Login" is pressed:
/// authenticate, look up the account's saved role, then redirect straight
/// into that role's workspace. This is the smart router described in the
/// spec — Visitor → Marketplace Feed, Affiliater → Token Dashboard,
/// Agent/Broker → Listing Manager, Investor → Portfolio Portal.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
      // 1. Authenticate.
      final user = await _authService.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;

      // 2. Smart router — the account's saved role decides the destination.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => dashboardForRole(user.role, user)),
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
                Text('Welcome back', style: textTheme.displayLarge?.copyWith(fontSize: 28)),
                const SizedBox(height: 6),
                Text(
                  "We'll take you straight to your workspace.",
                  style: textTheme.bodyLarge?.copyWith(color: AppColors.slate),
                ),

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

                PrimaryButton(label: 'Log In', isLoading: _isLoading, onPressed: _submit),

                const SizedBox(height: AppSpacing.lg),

                Center(
                  child: GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                            ),
                    child: RichText(
                      text: TextSpan(
                        style: textTheme.bodyMedium,
                        children: const [
                          TextSpan(text: "Don't have an account?  "),
                          TextSpan(text: 'Choose your path', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
