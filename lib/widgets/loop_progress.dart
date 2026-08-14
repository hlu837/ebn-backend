import 'package:flutter/material.dart';
import '../providers/loop_controller.dart';
import '../theme/app_theme.dart';

/// Slim horizontal tracker shown at the top of all three dashboards so
/// whoever is watching can see exactly where the live request stands,
/// no matter which side of the app they're looking at.
class LoopProgress extends StatelessWidget {
  const LoopProgress({super.key, required this.stage, this.idleContent});

  final LoopStage stage;

  /// Optional replacement for the default "No active request yet…" idle
  /// message — e.g. the Visitor dashboard swaps it for quick-start links.
  /// Other dashboards that don't pass this keep the default text.
  final Widget? idleContent;

  static const _labels = ['Tour\nRequested', 'Admin\nApproved', 'Agent\nDispatched', 'Tour\nConfirmed'];

  int get _completed => switch (stage) {
        LoopStage.idle => -1,
        LoopStage.searching => 0,
        LoopStage.pendingApproval => 0,
        LoopStage.broadcasting => 1,
        LoopStage.dispatched => 2,
        LoopStage.accepted => 3,
        LoopStage.declined => 1,
        LoopStage.expired => 1,
      };

  bool get _isFailure => stage == LoopStage.declined || stage == LoopStage.expired;

  @override
  Widget build(BuildContext context) {
    if (stage == LoopStage.idle) {
      return Container(
        width: double.infinity,
        color: AppColors.card,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
        child: idleContent ??
            const Text(
              'No active request yet — start one from the Visitor side.',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate),
            ),
      );
    }

    return Container(
      width: double.infinity,
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
      child: Row(
        children: List.generate(_labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final leftIndex = (i - 1) ~/ 2;
            final filled = leftIndex < _completed;
            return Expanded(
              child: Container(
                height: 2,
                color: filled ? AppColors.ink : AppColors.border,
              ),
            );
          }
          final index = i ~/ 2;
          final isFailedStep = _isFailure && index == 2;
          final isDone = index < _completed;
          final isCurrent = index == _completed;
          return _StepDot(
            label: _labels[index],
            done: isDone,
            current: isCurrent && !_isFailure,
            failed: isFailedStep,
          );
        }),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.done, required this.current, required this.failed});

  final String label;
  final bool done;
  final bool current;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final Color circleColor = failed
        ? AppColors.danger
        : done
            ? AppColors.ink
            : current
                ? AppColors.primaryYellow
                : AppColors.border;
    final Color iconOrTextColor = failed || done ? Colors.white : AppColors.ink;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: failed
              ? const Icon(Icons.close_rounded, size: 15, color: Colors.white)
              : done
                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                  : Text(
                      '${_dotNumber(label)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: iconOrTextColor),
                    ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: failed ? AppColors.danger : (done || current) ? AppColors.ink : AppColors.slate,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  int _dotNumber(String label) => LoopProgress._labels.indexOf(label) + 1;
}
