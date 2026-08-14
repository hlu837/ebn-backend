import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import 'signup_screen.dart';

const List<UserRole> _selectableRoles = [
  UserRole.user,
  UserRole.affiliater,
  UserRole.agent,
  UserRole.investor,
];

/// Step 1 of sign-up: capture intent before anyone sees an email/password
/// field, so the registration form (and eventually the dashboard) can be
/// built for the right role from the start.
class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key, this.initialRole});

  /// Pre-highlights a card — e.g. when arriving from a landing page card
  /// that already signaled intent. The user still confirms with "Next".
  final UserRole? initialRole;

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  UserRole? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialRole;
  }

  void _next() {
    if (_selected == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SignUpScreen(initialRole: _selected!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Choose your path', style: textTheme.displayLarge?.copyWith(fontSize: 28)),
                    const SizedBox(height: 6),
                    Text(
                      "Pick how you'll use EBN — you can always add another role later.",
                      style: textTheme.bodyLarge?.copyWith(color: AppColors.slate),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.86,
                      children: [
                        for (final role in _selectableRoles)
                          _RoleCard(
                            role: role,
                            selected: _selected == role,
                            onTap: () => setState(() => _selected = role),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                child: PrimaryButton(
                  label: _selected == null ? 'Select a path to continue' : 'Next',
                  onPressed: _selected == null ? null : _next,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.selected, required this.onTap});

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryYellow.withValues(alpha: 0.1) : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: selected ? AppColors.ink : AppColors.border, width: selected ? 2.5 : 1),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: const BoxDecoration(color: Color(0xFFF0F0EE), shape: BoxShape.circle),
                    child: Icon(role.pitchIcon, color: const Color(0xFF4A4A45), size: 20),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(role.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      role.pitchLine,
                      style: const TextStyle(fontSize: 12, color: AppColors.slate, height: 1.35),
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: AppColors.primaryYellow, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
