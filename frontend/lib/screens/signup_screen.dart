import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_buttons.dart';
import 'login_screen.dart';
import 'role_router.dart';
import 'role_select_screen.dart';

/// Step 2 of sign-up: the registration form. The role was already chosen
/// on [RoleSelectScreen], so this form just adapts its fields to match —
/// no toggle to re-pick it here, only a "Change" link back to that gate.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, required this.initialRole});

  final UserRole initialRole;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _agencyCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _fractionalInterest = false;
  bool _referralWasAutoFilled = false;

  UserRole get _role => widget.initialRole;

  @override
  void initState() {
    super.initState();
    // If this link came from an affiliater (e.g. ebn.app/?ref=AGT-4F82K),
    // auto-fill and lock in credit for them.
    final refFromLink = Uri.base.queryParameters['ref'];
    if (refFromLink != null && refFromLink.trim().isNotEmpty) {
      _referralCtrl.text = refFromLink.trim();
      _referralWasAutoFilled = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _agencyCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = await _authService.signUp(
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        phone: _phoneCtrl.text.trim(),
        role: _role,
        agencyOrLicense: _role == UserRole.agent ? _agencyCtrl.text : null,
        interestedInFractionalInvesting: _role == UserRole.investor && _fractionalInterest,
        referralCode: (_role == UserRole.agent || _role == UserRole.investor) ? null : _referralCtrl.text,
        agentReferralCode: _role == UserRole.agent ? _referralCtrl.text : null,
        investorReferralCode: _role == UserRole.investor ? _referralCtrl.text : null,
      );
      if (!mounted) return;

      AppToast.showSuccess(context, 'Welcome, ${user.fullName.split(' ').first}!');

      final destination = dashboardForRole(_role, user);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
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
                Row(
                  children: [
                    Expanded(child: Text(_role.signupHeadline, style: textTheme.displayLarge?.copyWith(fontSize: 28))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_role.signupSubtitle, style: textTheme.bodyLarge?.copyWith(color: AppColors.slate)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => RoleSelectScreen(initialRole: _role)),
                          ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_role.pitchIcon, size: 15, color: AppColors.slate),
                      const SizedBox(width: 6),
                      Text('Signing up as ${_role.label}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.slate)),
                      const SizedBox(width: 6),
                      const Text('· Change', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full Name', hintText: 'Jordan Rivera'),
                  validator: Validators.fullName,
                ),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', hintText: 'you@example.com'),
                  validator: Validators.email,
                ),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone', hintText: '+1 555 123 4567'),
                  validator: Validators.phone,
                ),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'At least 6 characters',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: Validators.password,
                ),

                // --- Role-specific fields ---
                if (_role == UserRole.agent) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _agencyCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Agency Name / License-ID Number',
                      hintText: 'e.g. Meridian Realty · LIC-88213',
                    ),
                    validator: (v) => Validators.notEmpty(v, label: 'Agency name or license number'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "We'll verify this before your listings go live — it's how we keep the marketplace trustworthy.",
                    style: TextStyle(fontSize: 11.5, color: AppColors.slate, height: 1.4),
                  ),
                ],

                if (_role == UserRole.investor) ...[
                  const SizedBox(height: AppSpacing.md),
                  _CheckboxRow(
                    value: _fractionalInterest,
                    onChanged: (v) => setState(() => _fractionalInterest = v),
                    label: 'I am interested in fractional property investments.',
                  ),
                ],

                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _referralCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: _role == UserRole.agent
                        ? 'Agent Network Code (optional)'
                        : _role == UserRole.investor
                            ? 'Investor Referral Code (optional)'
                            : 'Referral Code / Link (optional)',
                    hintText: _role == UserRole.agent
                        ? 'e.g. AGT-4F82K — from an agent who invited you'
                        : _role == UserRole.investor
                            ? 'e.g. INV-4F82K — from an investor who invited you'
                            : 'e.g. EBN-4F82K',
                    filled: _referralWasAutoFilled,
                    fillColor: AppColors.primaryYellow.withOpacity(0.12),
                  ),
                ),
                if (_referralWasAutoFilled) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 14, color: AppColors.slate),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _role == UserRole.agent
                              ? "You came from another agent's network link — they'll be your sponsor and earn a share of your commissions."
                              : _role == UserRole.investor
                                  ? "You came from another investor's referral link — they'll earn a reward once your first commitment is confirmed."
                                  : "You came from an affiliater's link — they'll get credit for this signup.",
                          style: const TextStyle(fontSize: 11.5, color: AppColors.slate, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                PrimaryButton(label: 'Create Account', isLoading: _isLoading, onPressed: _submit),

                const SizedBox(height: AppSpacing.lg),

                Center(
                  child: GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            ),
                    child: RichText(
                      text: TextSpan(
                        style: textTheme.bodyMedium,
                        children: const [
                          TextSpan(text: 'Already have an account?  '),
                          TextSpan(text: 'Sign In', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
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

class _CheckboxRow extends StatelessWidget {
  const _CheckboxRow({required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: AppColors.ink,
                checkColor: AppColors.primaryYellow,
              ),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.3)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
