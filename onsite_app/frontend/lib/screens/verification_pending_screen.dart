import 'package:flutter/material.dart';
import '../models/auth_response.dart';
import '../models/role_upgrade_request.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/role_upgrade_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import 'login_screen.dart';
import 'role_router.dart';

class VerificationPendingScreen extends StatefulWidget {
  const VerificationPendingScreen({
    super.key,
    required this.user,
    required this.targetRole,
    this.pendingRequest,
  });

  final AppUser user;
  final UserRole targetRole;
  final RoleUpgradeRequest? pendingRequest;

  @override
  State<VerificationPendingScreen> createState() => _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  final _roleUpgradeService = RoleUpgradeService();
  final _authService = AuthService();

  bool _checking = false;
  RoleUpgradeRequest? _request;
  String? _error;

  @override
  void initState() {
    super.initState();
    _request = widget.pendingRequest;
    _checkStatus(silent: true);
  }

  Future<void> _checkStatus({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _checking = true;
        _error = null;
      });
    }

    try {
      // 1. Check if the backend user role has updated
      final token = widget.user.token ?? '';
      final updatedUser = await _authService.me(token);

      if (updatedUser.role == widget.targetRole) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account Approved! Welcome to EBN ${widget.targetRole.label} Network.')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => dashboardForRole(updatedUser.role, updatedUser)),
          (route) => false,
        );
        return;
      }

      // 2. Fetch latest request status
      final requests = await _roleUpgradeService.myRequests(token: token);
      RoleUpgradeRequest? latest;
      for (final r in requests) {
        if (r.requestedRole == widget.targetRole) {
          latest = r;
          break;
        }
      }

      if (latest != null && latest.status == RoleUpgradeStatus.approved) {
        // Double check: if request approved, prompt relogin or try to route
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => dashboardForRole(widget.targetRole, updatedUser.copyWithToken(token))),
          (route) => false,
        );
        return;
      }

      if (mounted) {
        setState(() {
          _request = latest;
          _checking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _checking = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final req = _request;

    // Determine status stages
    final isSubmitted = req != null;
    final isPending = req == null || req.status == RoleUpgradeStatus.pending;
    final isRejected = req != null && req.status == RoleUpgradeStatus.rejected;

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Verification Status',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.slate),
            onPressed: _logout,
            tooltip: 'Log Out',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isRejected
                      ? AppColors.danger.withOpacity(0.12)
                      : theme.primaryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  isRejected
                      ? Icons.error_outline_rounded
                      : Icons.hourglass_empty_rounded,
                  color: isRejected ? AppColors.danger : theme.primaryColor,
                  size: 38,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                isRejected ? 'Verification Declined' : 'Verification Pending',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  isRejected
                      ? 'The administrator declined your payment verification request. Please review the reason below and resubmit.'
                      : 'We are reviewing your bank transfer receipt. Verification typically takes 12-24 hours.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.slate, height: 1.3),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Status timeline card
              if (!isRejected)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _TimelineStep(
                        title: 'Receipt Submitted',
                        subtitle: req != null
                            ? 'Submitted on ${req.createdAt.month}/${req.createdAt.day}/${req.createdAt.year}'
                            : 'Awaiting submission details',
                        isActive: true,
                        isCompleted: isSubmitted,
                      ),
                      _TimelineStep(
                        title: 'Admin Verification',
                        subtitle: 'Reviewing transfer reference and receipt copy',
                        isActive: isSubmitted && isPending,
                        isCompleted: false,
                        showLine: true,
                      ),
                      _TimelineStep(
                        title: 'Workspace Active',
                        subtitle: 'Gain full access to the ${widget.targetRole.label} network',
                        isActive: false,
                        isCompleted: false,
                        showLine: true,
                      ),
                    ],
                  ),
                ),

              if (isRejected) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rejection Reason:',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.danger),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        req.adminNote ?? 'No details provided by the administrator.',
                        style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: 'Resubmit Receipt',
                    backgroundColor: theme.primaryColor,
                    onPressed: () {
                      // Navigate back to plan selection to let them upload a new receipt
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => widget.targetRole == UserRole.agent
                              ? const LoginScreen() // Force a reload/recheck
                              : const LoginScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const Spacer(),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),

              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => dashboardForRole(widget.targetRole, widget.user)),
                    (route) => false,
                  );
                },
                child: Text(
                  'Continue to ${widget.targetRole.label} Workspace',
                  style: const TextStyle(color: AppColors.slate, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.isCompleted,
    this.showLine = false,
  });

  final String title;
  final String subtitle;
  final bool isActive;
  final bool isCompleted;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dotColor = isCompleted
        ? AppColors.success
        : isActive
            ? theme.primaryColor
            : AppColors.border;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            if (showLine)
              Container(
                width: 2,
                height: 24,
                color: isCompleted ? AppColors.success : AppColors.border,
              ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: dotColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: dotColor, width: 2),
              ),
              alignment: Alignment.center,
              child: isCompleted
                  ? const Icon(Icons.check_rounded, color: AppColors.success, size: 14)
                  : Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive ? theme.primaryColor : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isActive || isCompleted ? AppColors.ink : AppColors.slate,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.slate, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
