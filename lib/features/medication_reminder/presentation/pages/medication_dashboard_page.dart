import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/app_theme.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoSync());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    unawaited(widget.repository.stopAutoSync());
    super.dispose();
  }

  Future<void> _startAutoSync() async {
    await widget.repository.startAutoSync(uid: widget.uid);
    if (mounted) {
      setState(_load);
    }
  }

  void _load() {
    _medicationsFuture = widget.repository.getAll(uid: widget.uid);
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(_load);
    }
    await _medicationsFuture;
  }

  Future<void> _backup() async {
    try {
      await widget.repository.backupToCloud(uid: widget.uid);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('backup_complete'))));
        setState(_load);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('backup_waiting'))));
      }
    }
  }

  Future<void> _openAddPage() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AddReminderPage(repository: widget.repository, uid: widget.uid),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.ivory,
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
                    backgroundColor: AppPalette.ivory,
                    elevation: 0,
                    title: const Text(
                      'MediMind',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    actions: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LanguageToggleButton(),
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
                        nextMedication: nextMedication,
                        countdownText: _formatCountdown(nextMedication),
                        remaining: nextMedication == null
                            ? null
                            : _nextTime(nextMedication).difference(_now),
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
                  if (medications.isNotEmpty)
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
    required this.nextMedication,
    required this.countdownText,
    required this.remaining,
  });

  final Medication? nextMedication;
  final String countdownText;
  final Duration? remaining;

  @override
  Widget build(BuildContext context) {
    final remainingMinutes = remaining?.inMinutes ?? 0;
    final dayFraction = nextMedication == null
        ? 0.0
        : (remainingMinutes / Duration.minutesPerDay).clamp(0.015, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.aubergine, AppPalette.plum, AppPalette.persimmon],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppPalette.aubergine.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.medication_liquid_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nextMedication == null
                      ? context.tr('no_active_medicines')
                      : context.tr('next_medicine'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            nextMedication?.medicineName ?? context.tr('add_first_reminder'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 5),
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
          const SizedBox(height: 10),
          SizedBox(
            height: 148,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DayCyclePainter(progress: dayFraction),
                  ),
                ),
                Positioned(
                  left: 4,
                  bottom: 0,
                  child: Text(
                    context.tr('now'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  right: 2,
                  bottom: 0,
                  child: Text(
                    nextMedication?.timeOfDay ?? '--:--',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCyclePainter extends CustomPainter {
  const _DayCyclePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = math.min(size.width - 32, (size.height - 20) * 2);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 12),
      width: diameter,
      height: diameter,
    );
    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: math.pi,
        endAngle: math.pi * 2,
        colors: [AppPalette.saffron, Color(0xFFFFE0A0)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi, false, basePaint);
    if (progress > 0) {
      canvas.drawArc(rect, math.pi, math.pi * progress, false, progressPaint);
      final markerAngle = math.pi + math.pi * progress;
      final marker = Offset(
        rect.center.dx + rect.width / 2 * math.cos(markerAngle),
        rect.center.dy + rect.height / 2 * math.sin(markerAngle),
      );
      canvas.drawCircle(marker, 7, Paint()..color = Colors.white);
      canvas.drawCircle(marker, 3.5, Paint()..color = AppPalette.saffron);
    }
  }

  @override
  bool shouldRepaint(covariant _DayCyclePainter oldDelegate) {
    return oldDelegate.progress != progress;
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
        side: BorderSide(color: AppPalette.plum.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppPalette.persimmon),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: AppPalette.muted)),
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
            color: AppPalette.muted,
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
        side: BorderSide(color: AppPalette.plum.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppPalette.blush.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.medication_outlined,
                size: 36,
                color: AppPalette.persimmon,
              ),
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
        side: BorderSide(color: AppPalette.plum.withValues(alpha: 0.14)),
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
                  color: AppPalette.blush.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.medication_outlined,
                  color: AppPalette.persimmon,
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
                      style: const TextStyle(color: AppPalette.muted),
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
        color: AppPalette.blush.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppPalette.aubergine),
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
