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

  String _canonicalTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveCheckIn(
    Medication medication,
    DateTime scheduledTime,
    MedicationCheckIn Function(MedicationCheckIn current) update,
  ) async {
    final doseTime = _canonicalTime(scheduledTime);
    final current =
        medication.checkInFor(scheduledTime, doseTime) ??
        MedicationCheckIn(
          dateKey: medicationDateKey(scheduledTime),
          doseTime: doseTime,
        );
    final updatedCheckIn = update(current);
    final checkIns =
        medication.checkIns
            .where((item) => item.key != updatedCheckIn.key)
            .toList(growable: true)
          ..add(updatedCheckIn);
    await widget.repository.update(
      uid: widget.uid,
      medication: medication.copyWith(
        checkIns: checkIns,
        updatedAt: DateTime.now(),
      ),
    );
    if (mounted) {
      setState(_load);
    }
  }

  Future<void> _recordMedicineTaken(
    Medication medication,
    DateTime scheduledTime, {
    required DateTime takenAt,
    required bool withMeal,
  }) {
    return _saveCheckIn(
      medication,
      scheduledTime,
      (current) => MedicationCheckIn(
        dateKey: current.dateKey,
        doseTime: current.doseTime,
        medicineStatus: 'taken',
        mealStatus: withMeal ? 'taken' : current.mealStatus,
        medicineTakenAt: takenAt,
        mealTakenAt: withMeal ? takenAt : current.mealTakenAt,
        takenWithMeal: withMeal,
      ),
    );
  }

  Future<void> _recordMedicineNotTaken(
    Medication medication,
    DateTime scheduledTime,
  ) {
    return _saveCheckIn(
      medication,
      scheduledTime,
      (current) => MedicationCheckIn(
        dateKey: current.dateKey,
        doseTime: current.doseTime,
        medicineStatus: 'notTaken',
        mealStatus: current.mealStatus,
        mealTakenAt: current.mealTakenAt,
      ),
    );
  }

  Future<void> _recordMealStatus(
    Medication medication,
    DateTime scheduledTime, {
    required bool taken,
  }) {
    return _saveCheckIn(
      medication,
      scheduledTime,
      (current) => MedicationCheckIn(
        dateKey: current.dateKey,
        doseTime: current.doseTime,
        medicineStatus: current.medicineStatus,
        mealStatus: taken ? 'taken' : 'notTaken',
        medicineTakenAt: current.medicineTakenAt,
        mealTakenAt: taken ? DateTime.now() : null,
        takenWithMeal: taken && current.takenWithMeal,
      ),
    );
  }

  Future<void> _chooseTakenStatus(
    Medication medication,
    DateTime scheduledTime,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('when_taken'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, 'now'),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(context.tr('taken_now')),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(context, 'withMeal'),
                icon: const Icon(Icons.restaurant_outlined),
                label: Text(context.tr('taken_with_food')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'later'),
                icon: const Icon(Icons.schedule),
                label: Text(context.tr('taken_later')),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) {
      return;
    }
    if (choice == 'now' || choice == 'withMeal') {
      await _recordMedicineTaken(
        medication,
        scheduledTime,
        takenAt: DateTime.now(),
        withMeal: choice == 'withMeal',
      );
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: context.tr('choose_actual_time'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (!mounted || picked == null) {
      return;
    }
    final withMeal = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('also_with_food')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('without_food')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('taken_with_food')),
          ),
        ],
      ),
    );
    if (withMeal == null) {
      return;
    }
    final today = DateTime.now();
    await _recordMedicineTaken(
      medication,
      scheduledTime,
      takenAt: DateTime(
        today.year,
        today.month,
        today.day,
        picked.hour,
        picked.minute,
      ),
      withMeal: withMeal,
    );
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
    final clockTimes = times.isEmpty ? <String>[medication.timeOfDay] : times;
    for (var dayOffset = 0; dayOffset <= 366; dayOffset++) {
      final day = DateTime(_now.year, _now.month, _now.day + dayOffset);
      if (!medication.occursOnDate(day)) {
        continue;
      }
      final candidates =
          clockTimes
              .map((time) => _dateAtDashboardTime(day, time))
              .where((time) => !time.isBefore(_now))
              .toList(growable: false)
            ..sort();
      if (candidates.isNotEmpty) {
        return candidates.first;
      }
    }

    // Custom intervals are capped at 365 days, so this is only a defensive
    // fallback for malformed legacy records.
    return _dateAtDashboardTime(
      DateTime(_now.year, _now.month, _now.day + 1),
      clockTimes.first,
    );
  }

  DateTime _trackingTime(Medication medication) {
    final times = medication.effectiveDoses
        .map((dose) => dose.timeOfDay)
        .where((time) => time.isNotEmpty)
        .toList(growable: false);
    if (times.isEmpty) {
      return _nextTime(medication);
    }

    final today = DateTime(_now.year, _now.month, _now.day);
    final candidates = times
        .map((time) => _dateAtDashboardTime(today, time))
        .toList(growable: false);
    candidates.sort((left, right) {
      final leftDistance = left.difference(_now).inMinutes.abs();
      final rightDistance = right.difference(_now).inMinutes.abs();
      final distanceComparison = leftDistance.compareTo(rightDistance);
      return distanceComparison != 0
          ? distanceComparison
          : left.compareTo(right);
    });
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
            final todayMedications = medications
                .where((medication) => medication.occursOnDate(_now))
                .toList(growable: false);
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
                            value: '${todayMedications.length}',
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
                            '${todayMedications.length} ${context.tr('dashboard_items')}',
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
                  else if (todayMedications.isEmpty)
                    const SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(child: _NoMedicineToday()),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.separated(
                        itemBuilder: (context, index) {
                          final medication = todayMedications[index];
                          final nextTime = _nextTime(medication);
                          final trackingTime = _trackingTime(medication);
                          final checkIn = medication.checkInFor(
                            trackingTime,
                            _canonicalTime(trackingTime),
                          );
                          return _MedicineCard(
                            medication: medication,
                            nextTime: nextTime,
                            checkIn: checkIn,
                            onMedicineTaken: () =>
                                _chooseTakenStatus(medication, trackingTime),
                            onMedicineNotTaken: () => _recordMedicineNotTaken(
                              medication,
                              trackingTime,
                            ),
                            onMealTaken: () => _recordMealStatus(
                              medication,
                              trackingTime,
                              taken: true,
                            ),
                            onMealNotTaken: () => _recordMealStatus(
                              medication,
                              trackingTime,
                              taken: false,
                            ),
                            onTap: () => _showMedicationSheet(medication),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemCount: todayMedications.length,
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
                value: MaterialLocalizations.of(context).formatTimeOfDay(
                  _parseDashboardTime(medication.timeOfDay),
                  alwaysUse24HourFormat: false,
                ),
              ),
              _DetailLine(
                label: context.tr('schedule'),
                value: _localizedSchedule(context, medication),
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
                    nextMedication == null
                        ? '--:--'
                        : MaterialLocalizations.of(context).formatTimeOfDay(
                            _parseDashboardTime(nextMedication!.timeOfDay),
                            alwaysUse24HourFormat: false,
                          ),
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

class _NoMedicineToday extends StatelessWidget {
  const _NoMedicineToday();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppPalette.plum.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(
              Icons.event_available_outlined,
              color: AppPalette.persimmon,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr('no_medicine_today'))),
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
    required this.checkIn,
    required this.onMedicineTaken,
    required this.onMedicineNotTaken,
    required this.onMealTaken,
    required this.onMealNotTaken,
    required this.onTap,
  });

  final Medication medication;
  final DateTime nextTime;
  final MedicationCheckIn? checkIn;
  final VoidCallback onMedicineTaken;
  final VoidCallback onMedicineNotTaken;
  final VoidCallback onMealTaken;
  final VoidCallback onMealNotTaken;
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
                              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(nextTime), alwaysUse24HourFormat: false)}',
                          icon: Icons.schedule,
                        ),
                        _InfoChip(
                          label: _localizedSchedule(context, medication),
                          icon: Icons.event_repeat_outlined,
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
                    const SizedBox(height: 12),
                    _StatusActions(
                      title: context.tr('medicine_status'),
                      status: checkIn?.medicineStatus,
                      takenAt: checkIn?.medicineTakenAt,
                      takenWithMeal: checkIn?.takenWithMeal ?? false,
                      onTaken: onMedicineTaken,
                      onNotTaken: onMedicineNotTaken,
                    ),
                    if (medication.mealScheduleEnabled) ...[
                      const SizedBox(height: 10),
                      _StatusActions(
                        title: context.tr('meal_status'),
                        status: checkIn?.mealStatus,
                        takenAt: checkIn?.mealTakenAt,
                        onTaken: onMealTaken,
                        onNotTaken: onMealNotTaken,
                      ),
                    ],
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

class _StatusActions extends StatelessWidget {
  const _StatusActions({
    required this.title,
    required this.status,
    required this.takenAt,
    required this.onTaken,
    required this.onNotTaken,
    this.takenWithMeal = false,
  });

  final String title;
  final String? status;
  final DateTime? takenAt;
  final bool takenWithMeal;
  final VoidCallback onTaken;
  final VoidCallback onNotTaken;

  @override
  Widget build(BuildContext context) {
    final isTaken = status == 'taken';
    final isNotTaken = status == 'notTaken';
    final statusText = isTaken
        ? context.tr('status_taken')
        : isNotTaken
        ? context.tr('status_not_taken')
        : context.tr('status_pending');
    final detail = takenAt == null
        ? statusText
        : '$statusText • ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(takenAt!), alwaysUse24HourFormat: false)}${takenWithMeal ? ' • ${context.tr('with_food')}' : ''}';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppPalette.ivory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.plum.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  detail,
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: isTaken
                        ? AppPalette.aubergine
                        : isNotTaken
                        ? AppPalette.persimmon
                        : AppPalette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onNotTaken,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Text(context.tr('mark_not_taken')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onTaken,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Text(context.tr('mark_taken')),
                ),
              ),
            ],
          ),
        ],
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
          'unit' => context.tr('units'),
          _ => context.tr('pill'),
        };
        final displayTime = MaterialLocalizations.of(context).formatTimeOfDay(
          _parseDashboardTime(dose.timeOfDay),
          alwaysUse24HourFormat: false,
        );
        return '$displayTime — ${dose.dosageValue} $unit';
      })
      .join(' • ');
}

String _localizedSchedule(BuildContext context, Medication medication) {
  if (medication.scheduleFrequency != 'custom') {
    return context.tr(medication.scheduleFrequency);
  }
  final days = medication.customIntervalDays.clamp(1, 365);
  final isBangla = AppLanguageScope.controllerOf(context).languageCode == 'bn';
  return isBangla
      ? '${context.tr('every_n_days')} $days ${context.tr('days')} পরপর'
      : '${context.tr('every_n_days')} $days ${context.tr('days')}';
}

DateTime _dateAtDashboardTime(DateTime date, String value) {
  final time = _parseDashboardTime(value);
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

TimeOfDay _parseDashboardTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
    minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}
