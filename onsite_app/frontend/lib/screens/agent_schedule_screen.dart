import 'package:flutter/material.dart';

import '../models/agent_account.dart';
import '../models/auth_response.dart';
import '../services/agent_service.dart';
import '../theme/app_theme.dart';

String _formatDayHeader(DateTime d) {
  const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  if (day == today) return 'Today · ${weekdays[d.weekday - 1]}';
  if (day == today.add(const Duration(days: 1))) return 'Tomorrow · ${weekdays[d.weekday - 1]}';
  return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}

String _formatTimeRange(DateTime start, Duration duration) {
  String fmt(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final suffix = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  return '${fmt(start)} – ${fmt(start.add(duration))}';
}

/// The agent's calendar of confirmed property tours and client bookings —
/// grouped by day, with reschedule/cancel actions. Backed by
/// `GET/POST/PATCH/DELETE /api/agents/:id/schedule`.
class AgentScheduleScreen extends StatefulWidget {
  const AgentScheduleScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AgentScheduleScreen> createState() => _AgentScheduleScreenState();
}

class _AgentScheduleScreenState extends State<AgentScheduleScreen> {
  final _service = AgentService();
  late Future<List<AgentBooking>> _future = _load();

  Future<List<AgentBooking>> _load() => _service.getSchedule(widget.user.id, token: widget.user.token ?? '');

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Map<DateTime, List<AgentBooking>> _grouped(List<AgentBooking> bookings) {
    final map = <DateTime, List<AgentBooking>>{};
    final sorted = [...bookings]..sort((a, b) => a.startAt.compareTo(b.startAt));
    for (final b in sorted) {
      final key = DateTime(b.startAt.year, b.startAt.month, b.startAt.day);
      map.putIfAbsent(key, () => []).add(b);
    }
    return map;
  }

  void _openBookingActions(AgentBooking booking) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cloud,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BookingActionsSheet(
        booking: booking,
        onReschedule: () {
          Navigator.of(context).pop();
          _openReschedule(booking);
        },
        onCancel: () async {
          Navigator.of(context).pop();
          try {
            await _service.cancelBooking(widget.user.id, booking.id, token: widget.user.token ?? '');
            if (!mounted) return;
            await _refresh();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Tour with ${booking.clientName} cancelled. Client notified automatically.')),
            );
          } on AgentServiceException catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          }
        },
      ),
    );
  }

  Future<void> _openReschedule(AgentBooking booking) async {
    final date = await showDatePicker(
      context: context,
      initialDate: booking.startAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(booking.startAt));
    if (time == null || !mounted) return;
    final newStart = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    try {
      await _service.updateBooking(widget.user.id, booking.id, startAt: newStart, status: 'pending', token: widget.user.token ?? '');
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reschedule requested for ${booking.clientName}. Client notified automatically.')),
      );
    } on AgentServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Schedule', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: FutureBuilder<List<AgentBooking>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error is AgentServiceException ? (snapshot.error as AgentServiceException).message : 'Something went wrong.',
              onRetry: _refresh,
            );
          }
          final grouped = _grouped(snapshot.data!);
          if (grouped.isEmpty) {
            return RefreshIndicator(onRefresh: _refresh, child: ListView(children: const [_EmptySchedule()]));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.primaryYellow.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadii.md)),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primaryYellow),
                      SizedBox(width: 8),
                      Expanded(child: Text('A 15-minute buffer and estimated travel time are held automatically between tours.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSoft))),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final day in grouped.keys) ...[
                  Text(_formatDayHeader(day).toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.slate, letterSpacing: 0.6)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final b in grouped[day]!) ...[
                    _BookingTile(booking: b, onTap: () => _openBookingActions(b)),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.slate),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: AppColors.slate)),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined, size: 40, color: AppColors.slate),
            SizedBox(height: AppSpacing.md),
            Text('No tours booked', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
            SizedBox(height: 6),
            Text('Accepted dispatches and client bookings will show up here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.slate)),
          ],
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking, required this.onTap});
  final AgentBooking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pending = booking.status == 'pending';
    final duration = Duration(minutes: booking.durationMinutes);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: AppColors.cloud, borderRadius: BorderRadius.circular(AppRadii.sm), border: Border.all(color: AppColors.border)),
                child: Column(
                  children: [
                    Text('${booking.startAt.hour % 12 == 0 ? 12 : booking.startAt.hour % 12}:${booking.startAt.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    Text(booking.startAt.hour >= 12 ? 'PM' : 'AM', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.slate)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(booking.propertyTitle, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (pending)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.primaryYellow.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.pill)),
                            child: const Text('Pending', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryYellow)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.pill)),
                            child: const Text('Confirmed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${booking.clientName} · ${_formatTimeRange(booking.startAt, duration)}', style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                    if (booking.address != null && booking.address!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: AppColors.slate),
                          const SizedBox(width: 3),
                          Expanded(child: Text(booking.address!, style: const TextStyle(fontSize: 12, color: AppColors.slate), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingActionsSheet extends StatelessWidget {
  const _BookingActionsSheet({required this.booking, required this.onReschedule, required this.onCancel});
  final AgentBooking booking;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: AppSpacing.md), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Text(booking.propertyTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text('with ${booking.clientName}', style: const TextStyle(fontSize: 12.5, color: AppColors.slate)),
          const SizedBox(height: AppSpacing.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_calendar_outlined, color: AppColors.ink),
            title: const Text('Reschedule', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
            subtitle: const Text('Client is notified automatically', style: TextStyle(fontSize: 12, color: AppColors.slate)),
            onTap: onReschedule,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy_outlined, color: AppColors.danger),
            title: const Text('Cancel tour', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.danger)),
            subtitle: const Text('Client is notified automatically', style: TextStyle(fontSize: 12, color: AppColors.slate)),
            onTap: onCancel,
          ),
        ],
      ),
    );
  }
}
