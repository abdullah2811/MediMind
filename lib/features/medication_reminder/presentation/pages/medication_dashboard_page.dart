import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/medication.dart';
import '../../domain/repositories/medication_repository.dart';
import 'add_reminder_page.dart';

class MedicationDashboardPage extends StatefulWidget {
  const MedicationDashboardPage({
    super.key,
    required this.uid,
    required this.repository,
    required this.onSignOut,
  });

  final String uid;
  final MedicationRepository repository;
  final Future<void> Function() onSignOut;

  @override
  State<MedicationDashboardPage> createState() =>
      _MedicationDashboardPageState();
}

class _MedicationDashboardPageState extends State<MedicationDashboardPage> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  Future<List<Medication>>? _medicationsFuture;

  @override
  void initState() {
    super.initState();
    _load();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAndRefresh();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _load() {
    _medicationsFuture = widget.repository.getAll(uid: widget.uid);
  }

  Future<void> _syncAndRefresh() async {
    await widget.repository.syncFromCloud(uid: widget.uid);
    if (mounted) {
      setState(_load);
    }
  }

  Future<void> _refresh() async {
    await _syncAndRefresh();
  }

  Future<void> _backup() async {
    await widget.repository.backupToCloud(uid: widget.uid);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Backup complete.')));
      setState(_load);
    }
  }

  Future<void> _openAddPage() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddReminderPage(
          repository: widget.repository,
          uid: widget.uid,
          onSignOut: widget.onSignOut,
        ),
      ),
    );
    if (changed == true && mounted) {
      setState(_load);
    }
  }

  Medication? _nextMedication(List<Medication> medications) {
    final active = medications
        .where((medication) => medication.isActive)
        .toList();
    if (active.isEmpty) {
      return null;
    }

    active.sort((left, right) => _nextTime(left).compareTo(_nextTime(right)));
    return active.first;
  }

  DateTime _nextTime(Medication medication) {
    final parts = medication.timeOfDay.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    var next = DateTime(_now.year, _now.month, _now.day, hour, minute);
    if (next.isBefore(_now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  String _formatCountdown(Medication? medication) {
    if (medication == null) {
      return 'No active medicines';
    }
    final diff = _nextTime(medication).difference(_now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m';
  }

  String _formatClock() {
    final hourOfPeriod = _now.hour % 12;
    final hour = hourOfPeriod == 0 ? 12 : hourOfPeriod;
    final minute = _now.minute.toString().padLeft(2, '0');
    final period = _now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: FutureBuilder<List<Medication>>(
          future: _medicationsFuture,
          builder: (context, snapshot) {
            final medications = snapshot.data ?? const <Medication>[];
            final activeMedications = medications
                .where((medication) => medication.isActive)
                .toList();
            final nextMedication = _nextMedication(medications);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    floating: true,
                    pinned: true,
                    backgroundColor: const Color(0xFFF4F7FB),
                    elevation: 0,
                    title: const Text(
                      'MediMind',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Refresh from cloud',
                        onPressed: _refresh,
                        icon: const Icon(Icons.sync),
                      ),
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: widget.onSignOut,
                        icon: const Icon(Icons.logout_outlined),
                      ),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: _HeroHeader(
                        timeText: _formatClock(),
                        nextMedication: nextMedication,
                        countdownText: _formatCountdown(nextMedication),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Today',
                              value: '${medications.length}',
                              icon: Icons.medication_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              title: 'Active',
                              value: '${activeMedications.length}',
                              icon: Icons.notifications_active_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              title: 'Next in',
                              value: _formatCountdown(nextMedication),
                              icon: Icons.schedule_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              button: true,
                              label: 'Add medicine',
                              child: FilledButton.icon(
                                onPressed: _openAddPage,
                                icon: const Icon(Icons.add),
                                label: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Add Medicine'),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Semantics(
                              button: true,
                              label: 'Backup medicine data to Firebase',
                              child: OutlinedButton.icon(
                                onPressed: _backup,
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Backup'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: 'আজকের ওষুধ',
                        trailing: '${medications.length} items',
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (medications.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: _EmptyState(onAdd: _openAddPage),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.separated(
                        itemBuilder: (context, index) {
                          final medication = medications[index];
                          return _MedicineCard(
                            medication: medication,
                            nextTime: _nextTime(medication),
                            onTap: () => _showMedicationSheet(medication),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemCount: medications.length,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showMedicationSheet(Medication medication) {
    final parentContext = context;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                medication.medicineName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _DetailLine(label: 'Dose', value: medication.dose),
              _DetailLine(
                label: 'Duration',
                value: '${medication.durationDays} days',
              ),
              _DetailLine(label: 'Time', value: medication.timeOfDay),
              if ((medication.formula ?? '').isNotEmpty)
                _DetailLine(label: 'Formula', value: medication.formula!),
              if ((medication.companyName ?? '').isNotEmpty)
                _DetailLine(label: 'Company', value: medication.companyName!),
              if ((medication.notes ?? '').isNotEmpty)
                _DetailLine(label: 'Notes', value: medication.notes!),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(parentContext);
                        await widget.repository.delete(
                          uid: widget.uid,
                          id: medication.id,
                        );
                        if (mounted) {
                          setState(_load);
                        }
                      },
                      child: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(parentContext);
                        final changed = await Navigator.of(parentContext)
                            .push<bool>(
                              MaterialPageRoute(
                                builder: (_) => AddReminderPage(
                                  repository: widget.repository,
                                  uid: widget.uid,
                                  onSignOut: widget.onSignOut,
                                  existingMedication: medication,
                                ),
                              ),
                            );
                        if (changed == true && mounted) {
                          setState(_load);
                        }
                      },
                      child: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.timeText,
    required this.nextMedication,
    required this.countdownText,
  });

  final String timeText;
  final Medication? nextMedication;
  final String countdownText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Dhaka, Bangladesh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                timeText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nextMedication == null
                          ? 'No active medicines'
                          : 'Next medicine',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nextMedication?.medicineName ?? 'Add a medicine reminder',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nextMedication == null
                          ? 'Create your first reminder to start notifications.'
                          : 'Due in $countdownText',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                  border: Border.all(color: Colors.white70, width: 4),
                ),
                child: Center(
                  child: Text(
                    nextMedication?.timeOfDay ?? '--:--',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF0F766E)),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          trailing,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.medication_outlined, size: 36),
            ),
            const SizedBox(height: 14),
            const Text(
              'No medicines saved yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a medicine once and the app will remind and back it up automatically.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAdd, child: const Text('Add Medicine')),
          ],
        ),
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({
    required this.medication,
    required this.nextTime,
    required this.onTap,
  });

  final Medication medication;
  final DateTime nextTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: medication.isActive
                      ? const Color(0xFFE8F7F3)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  medication.isActive
                      ? Icons.medication_outlined
                      : Icons.pause_circle_outline,
                  color: medication.isActive
                      ? const Color(0xFF0F766E)
                      : Colors.grey,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            medication.medicineName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          medication.isActive ? 'Active' : 'Paused',
                          style: TextStyle(
                            color: medication.isActive
                                ? const Color(0xFF0F766E)
                                : Colors.grey,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      medication.dose.isEmpty
                          ? 'Dose not set'
                          : medication.dose,
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          label: medication.timeOfDay,
                          icon: Icons.schedule,
                        ),
                        _InfoChip(
                          label: '${medication.durationDays} days',
                          icon: Icons.calendar_month_outlined,
                        ),
                        if ((medication.companyName ?? '').isNotEmpty)
                          _InfoChip(
                            label: medication.companyName!,
                            icon: Icons.apartment_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${nextTime.hour.toString().padLeft(2, '0')}:${nextTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Next', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF334155)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
