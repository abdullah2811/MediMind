import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/services/medication_notification_service.dart';
import '../../domain/models/medication.dart';
import '../../domain/repositories/medication_repository.dart';
import '../../domain/services/medication_image_data.dart';
import 'add_reminder_page.dart';
import 'medication_report_page.dart';

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

class _MedicationDashboardPageState extends State<MedicationDashboardPage>
    with WidgetsBindingObserver {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  Future<List<Medication>>? _medicationsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    unawaited(widget.repository.stopAutoSync());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(_load);
    }
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

  Future<void> _openReports() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MedicationReportPage(
          uid: widget.uid,
          repository: widget.repository,
        ),
      ),
    );
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

  String _formatCountdown(DateTime? scheduledAt) {
    if (scheduledAt == null) {
      return context.tr('no_active_medicines');
    }
    final diff = scheduledAt.difference(_now);
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
            final upcomingEvents = buildMedicationReminderPlan(
              medications,
              from: _now,
              horizonDays: 366,
              maxEvents: 4,
            );
            final startOfToday = DateTime(_now.year, _now.month, _now.day);
            final todayEvents = buildMedicationReminderPlan(
              medications,
              from: startOfToday.subtract(const Duration(milliseconds: 1)),
              horizonDays: 0,
              maxEvents: 360,
            );
            final nextEvent = upcomingEvents.isEmpty
                ? null
                : upcomingEvents.first;

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
                      IconButton(
                        tooltip: context.tr('reports'),
                        onPressed: _openReports,
                        icon: const Icon(Icons.assessment_outlined),
                      ),
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
                        upcomingEvents: upcomingEvents,
                        todayEvents: todayEvents,
                        countdownText: _formatCountdown(nextEvent?.scheduledAt),
                        now: _now,
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
                            value: _formatCountdown(nextEvent?.scheduledAt),
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
    required this.upcomingEvents,
    required this.todayEvents,
    required this.countdownText,
    required this.now,
  });

  final List<MedicationReminderPlanItem> upcomingEvents;
  final List<MedicationReminderPlanItem> todayEvents;
  final String countdownText;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final nextEvent = upcomingEvents.isEmpty ? null : upcomingEvents.first;
    final dayFraction = (now.hour * 60 + now.minute) / Duration.minutesPerDay;
    final headlineDate = nextEvent?.scheduledAt ?? now;
    final weekday = _localizedWeekday(context, headlineDate);
    final date = _localizedOrdinalDate(context, headlineDate);
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
          LayoutBuilder(
            builder: (context, constraints) {
              final railWidth = math.min(154.0, constraints.maxWidth * 0.48);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            weekday,
                            key: const ValueKey('hero-weekday'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            date,
                            key: const ValueKey('hero-date'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: railWidth,
                    height: 132,
                    child: _UpcomingEventRail(
                      events: upcomingEvents.take(3).toList(growable: false),
                      now: now,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 174,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DayCyclePainter(
                      progress: dayFraction,
                      eventFractions: todayEvents
                          .map(_eventDayFraction)
                          .toList(growable: false),
                    ),
                  ),
                ),
                Positioned(
                  left: 40,
                  right: 40,
                  top: 72,
                  child: Column(
                    children: [
                      Text(
                        nextEvent == null
                            ? context.tr('no_active_medicines')
                            : _eventLabel(context, nextEvent),
                        key: const ValueKey('hero-current-event'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        nextEvent == null
                            ? context.tr('create_first_reminder_hint')
                            : '${context.tr('due_in')} $countdownText',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 4,
                  bottom: 0,
                  child: Text(
                    _eventTime(context, now),
                    key: const ValueKey('hero-now-time'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Positioned(
                  right: 4,
                  bottom: 0,
                  child: Text(
                    '11:59 PM',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

class _UpcomingEventRail extends StatelessWidget {
  const _UpcomingEventRail({required this.events, required this.now});

  final List<MedicationReminderPlanItem> events;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Text(
          context.tr('no_upcoming_events'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      );
    }
    return Column(
      children: List.generate(
        events.length,
        (index) => Expanded(
          child: _UpcomingEventRailItem(
            event: events[index],
            now: now,
            isNext: index == 0,
            isLast: index == events.length - 1,
          ),
        ),
      ),
    );
  }
}

class _UpcomingEventRailItem extends StatelessWidget {
  const _UpcomingEventRailItem({
    required this.event,
    required this.now,
    required this.isNext,
    required this.isLast,
  });

  final MedicationReminderPlanItem event;
  final DateTime now;
  final bool isNext;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 16,
          child: Column(
            children: [
              Container(
                key: isNext ? const ValueKey('next-event-dot') : null,
                width: isNext ? 12 : 8,
                height: isNext ? 12 : 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isNext
                      ? AppPalette.saffron
                      : Colors.white.withValues(alpha: 0.35),
                  border: isNext
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _eventTimeWithDay(context, event.scheduledAt, now),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Manrope',
                  fontSize: isNext ? 12 : 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _eventLabel(context, event),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCyclePainter extends CustomPainter {
  const _DayCyclePainter({
    required this.progress,
    required this.eventFractions,
  });

  final double progress;
  final List<double> eventFractions;

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
    final safeProgress = progress.clamp(0.0, 1.0);
    if (safeProgress > 0) {
      canvas.drawArc(
        rect,
        math.pi,
        math.pi * safeProgress,
        false,
        progressPaint,
      );
    }

    for (final fraction in eventFractions.toSet()) {
      final safeFraction = fraction.clamp(0.0, 1.0);
      final point = _pointOnDayArc(rect, safeFraction);
      final hasPassed = safeFraction <= safeProgress;
      canvas.drawCircle(
        point,
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        3.5,
        Paint()
          ..color = hasPassed
              ? AppPalette.persimmon
              : AppPalette.aubergine.withValues(alpha: 0.72),
      );
    }

    final currentPoint = _pointOnDayArc(rect, safeProgress);
    canvas.drawCircle(currentPoint, 8, Paint()..color = Colors.white);
    canvas.drawCircle(currentPoint, 4.25, Paint()..color = AppPalette.saffron);
  }

  Offset _pointOnDayArc(Rect rect, double fraction) {
    final angle = math.pi + math.pi * fraction;
    return Offset(
      rect.center.dx + rect.width / 2 * math.cos(angle),
      rect.center.dy + rect.height / 2 * math.sin(angle),
    );
  }

  @override
  bool shouldRepaint(covariant _DayCyclePainter oldDelegate) {
    if (oldDelegate.progress != progress ||
        oldDelegate.eventFractions.length != eventFractions.length) {
      return true;
    }
    for (var index = 0; index < eventFractions.length; index++) {
      if (oldDelegate.eventFractions[index] != eventFractions[index]) {
        return true;
      }
    }
    return false;
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
    final nextLabel = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(nextTime),
      alwaysUse24HourFormat: false,
    );
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: AppPalette.plum.withValues(alpha: 0.14)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MedicineArtwork(medication: medication),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medication.medicineName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          <String>[
                            context.tr(medication.medicineType),
                            if (medication.powerLabel.isNotEmpty)
                              medication.powerLabel,
                          ].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.blush.withValues(alpha: 0.46),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 15,
                                color: AppPalette.aubergine,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${context.tr('next')}: $nextLabel',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppPalette.aubergine,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppPalette.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppPalette.ivory,
                      AppPalette.blush.withValues(alpha: 0.24),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppPalette.plum.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.medication_liquid_rounded,
                      size: 19,
                      color: AppPalette.persimmon,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        medication.dose.isEmpty
                            ? context.tr('dose_not_set')
                            : _localizedDoseSummary(context, medication),
                        style: const TextStyle(
                          color: AppPalette.aubergine,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    label: _localizedSchedule(context, medication),
                    icon: Icons.event_repeat_outlined,
                  ),
                  if ((medication.companyName ?? '').isNotEmpty)
                    _InfoChip(
                      label: medication.companyName!,
                      icon: Icons.apartment_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 14),
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
      ),
    );
  }
}

class _MedicineArtwork extends StatelessWidget {
  const _MedicineArtwork({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context) {
    final bytes = medicationImageBytes(medication);
    final networkUrl = medicationNetworkImageUrl(medication);
    Widget image;
    if (bytes != null) {
      image = Image.memory(
        bytes,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    } else if (networkUrl != null) {
      image = Image.network(
        networkUrl,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    } else {
      image = _fallback();
    }

    return Container(
      key: ValueKey('medicine-artwork-${medication.id}'),
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: AppPalette.aubergine.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: ColoredBox(color: AppPalette.blush, child: image),
      ),
    );
  }

  Widget _fallback() {
    final icon = switch (medication.medicineType) {
      'syrup' => Icons.local_drink_outlined,
      'drop' => Icons.water_drop_outlined,
      'insulin' => Icons.vaccines_outlined,
      _ => Icons.medication_outlined,
    };
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppPalette.blush, Color(0xFFFFE7D7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(icon, color: AppPalette.persimmon, size: 34),
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

String _eventLabel(BuildContext context, MedicationReminderPlanItem event) {
  final medicineNames = event.doses
      .map((item) => item.medication.medicineName)
      .toSet()
      .join(', ');
  final mealNames = event.meals
      .map((item) => item.medication.medicineName)
      .toSet()
      .join(', ');
  if (event.hasMedicine && event.hasMeal) {
    return '$medicineNames + ${context.tr('meal_event')}';
  }
  if (event.hasMedicine) {
    return medicineNames;
  }
  return '${context.tr('meal_event')} — $mealNames';
}

String _eventTime(BuildContext context, DateTime scheduledAt) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(scheduledAt),
    alwaysUse24HourFormat: false,
  );
}

double _eventDayFraction(MedicationReminderPlanItem event) {
  final time = event.scheduledAt;
  return (time.hour * 60 + time.minute) / Duration.minutesPerDay;
}

String _localizedWeekday(BuildContext context, DateTime date) {
  const english = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const bangla = <String>[
    'সোমবার',
    'মঙ্গলবার',
    'বুধবার',
    'বৃহস্পতিবার',
    'শুক্রবার',
    'শনিবার',
    'রবিবার',
  ];
  final isBangla = AppLanguageScope.controllerOf(context).languageCode == 'bn';
  return (isBangla ? bangla : english)[date.weekday - 1];
}

String _localizedOrdinalDate(BuildContext context, DateTime date) {
  const englishMonths = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  const banglaMonths = <String>[
    'জানুয়ারি',
    'ফেব্রুয়ারি',
    'মার্চ',
    'এপ্রিল',
    'মে',
    'জুন',
    'জুলাই',
    'আগস্ট',
    'সেপ্টেম্বর',
    'অক্টোবর',
    'নভেম্বর',
    'ডিসেম্বর',
  ];
  final isBangla = AppLanguageScope.controllerOf(context).languageCode == 'bn';
  if (isBangla) {
    return '${_toBanglaDigits(date.day)} ${banglaMonths[date.month - 1]}, '
        '${_toBanglaDigits(date.year)}';
  }
  final mod100 = date.day % 100;
  final suffix = mod100 >= 11 && mod100 <= 13
      ? 'th'
      : switch (date.day % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '${date.day}$suffix ${englishMonths[date.month - 1]}, ${date.year}';
}

String _toBanglaDigits(Object value) {
  const digits = <String>['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  return value
      .toString()
      .split('')
      .map((character) => int.tryParse(character))
      .map((digit) => digit == null ? '' : digits[digit])
      .join();
}

String _eventTimeWithDay(
  BuildContext context,
  DateTime scheduledAt,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final eventDay = DateTime(
    scheduledAt.year,
    scheduledAt.month,
    scheduledAt.day,
  );
  final dayDifference = eventDay.difference(today).inDays;
  final time = _eventTime(context, scheduledAt);
  if (dayDifference == 0) {
    return time;
  }
  if (dayDifference == 1) {
    return '${context.tr('tomorrow_short')} $time';
  }
  return '${scheduledAt.day.toString().padLeft(2, '0')}/'
      '${scheduledAt.month.toString().padLeft(2, '0')} $time';
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
