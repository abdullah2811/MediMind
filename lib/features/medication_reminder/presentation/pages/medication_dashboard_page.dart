import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localization.dart';
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
      ).showSnackBar(SnackBar(content: Text(context.tr('backup_complete'))));
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
    if (medications.isEmpty) {
      return null;
    }

    final scheduled = medications.toList(growable: false)
      ..sort((left, right) => _nextTime(left).compareTo(_nextTime(right)));
    return scheduled.first;
  }

  DateTime _nextTime(Medication medication) {
    final times = medication.effectiveDoses
        .map((dose) => dose.timeOfDay)
        .where((time) => time.isNotEmpty)
        .toList(growable: false);
    final candidates =
        (times.isEmpty ? <String>[medication.timeOfDay] : times)
            .map((time) {
              final parts = time.split(':');
              final hour = int.tryParse(parts.first) ?? 0;
              final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
              var next = DateTime(
                _now.year,
                _now.month,
                _now.day,
                hour,
                minute,
              );
              if (next.isBefore(_now)) {
                next = next.add(const Duration(days: 1));
              }
              return next;
            })
            .toList(growable: false)
          ..sort();
    return candidates.first;
  }

  String _formatCountdown(Medication? medication) {
    if (medication == null) {
      return context.tr('no_active_medicines');
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
                        tooltip: context.tr('refresh_from_cloud'),
                        onPressed: _refresh,
                        icon: const Icon(Icons.sync),
                      ),
                      IconButton(
                        tooltip: context.tr('sign_out'),
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
                      child: _Metrics(
                        cards: [
                          _MetricCard(
                            title: context.tr('today'),
                            value: '${medications.length}',
                            icon: Icons.medication_outlined,
                          ),
                          _MetricCard(
                            title: context.tr('dashboard_active'),
                            value: '${medications.length}',
                            icon: Icons.notifications_active_outlined,
                          ),
                          _MetricCard(
                            title: context.tr('dashboard_next_in'),
                            value: _formatCountdown(nextMedication),
                            icon: Icons.schedule_outlined,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ActionButtons(
                        primaryLabel: context.tr('add_medicine'),
                        secondaryLabel: context.tr('backup'),
                        onPrimary: _openAddPage,
                        onSecondary: _backup,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: _SectionTitle(
                        title: context.tr('dashboard_today'),
                        trailing:
                            '${medications.length} ${context.tr('dashboard_items')}',
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
              _DetailLine(
                label: context.tr('type'),
                value: context.tr(medication.medicineType),
              ),
              if (medication.powerLabel.isNotEmpty)
                _DetailLine(
                  label: context.tr('power'),
                  value: medication.powerLabel,
                ),
              _DetailLine(
                label: context.tr('dose'),
                value: _localizedDoseSummary(context, medication),
              ),
              _DetailLine(
                label: context.tr('time'),
                value: medication.timeOfDay,
              ),
              if ((medication.formula ?? '').isNotEmpty)
                _DetailLine(
                  label: context.tr('formula'),
                  value: medication.formula!,
                ),
              if ((medication.companyName ?? '').isNotEmpty)
                _DetailLine(
                  label: context.tr('company'),
                  value: medication.companyName!,
                ),
              if ((medication.notes ?? '').isNotEmpty)
                _DetailLine(
                  label: context.tr('notes'),
                  value: medication.notes!,
                ),
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
                      child: Text(context.tr('delete')),
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
                      child: Text(context.tr('edit')),
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
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nextMedication == null
              ? context.tr('no_active_medicines')
              : context.tr('next_medicine'),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          nextMedication?.medicineName ?? context.tr('add_first_reminder'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          nextMedication == null
              ? context.tr('create_first_reminder_hint')
              : '${context.tr('due_in')} $countdownText',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            height: 1.35,
          ),
        ),
      ],
    );
    final clock = Container(
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
    );
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
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.location_on_outlined, color: Colors.white),
              Text(
                context.tr('dhaka'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
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
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 430) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    details,
                    const SizedBox(height: 16),
                    Align(alignment: Alignment.centerRight, child: clock),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 14),
                  clock,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 500 ? 2 : 3;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(growable: false),
        );
      },
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });

  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 430;
        final primary = FilledButton.icon(
          onPressed: onPrimary,
          icon: const Icon(Icons.add),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(primaryLabel, textAlign: TextAlign.center),
          ),
        );
        final secondary = OutlinedButton.icon(
          onPressed: onSecondary,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(secondaryLabel, textAlign: TextAlign.center),
          ),
        );
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [primary, const SizedBox(height: 10), secondary],
          );
        }
        return Row(
          children: [
            Expanded(child: primary),
            const SizedBox(width: 12),
            Expanded(child: secondary),
          ],
        );
      },
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
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
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
            Text(
              context.tr('no_medicine_saved'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('empty_medicine_hint'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAdd,
              child: Text(context.tr('add_medicine')),
            ),
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
                  color: const Color(0xFFE8F7F3),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.medication_outlined,
                  color: const Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medication.medicineName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      medication.dose.isEmpty
                          ? context.tr('dose_not_set')
                          : _localizedDoseSummary(context, medication),
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          label:
                              '${context.tr('next')}: '
                              '${nextTime.hour.toString().padLeft(2, '0')}:'
                              '${nextTime.minute.toString().padLeft(2, '0')}',
                          icon: Icons.schedule,
                        ),
                        if (medication.powerLabel.isNotEmpty)
                          _InfoChip(
                            label: medication.powerLabel,
                            icon: Icons.science_outlined,
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

String _localizedDoseSummary(BuildContext context, Medication medication) {
  if (medication.doses.isEmpty) {
    return medication.dose;
  }
  return medication.doses
      .map((dose) {
        final unit = switch (dose.dosageUnit) {
          'ml' => context.tr('ml'),
          'drop' => context.tr('drop_unit'),
          _ => context.tr('pill'),
        };
        return '${dose.timeOfDay} — ${dose.dosageValue} $unit';
      })
      .join(' • ');
}
