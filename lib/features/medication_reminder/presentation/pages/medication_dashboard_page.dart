import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../core/formatting/app_time_format.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/services/medication_notification_service.dart';
import '../../domain/models/medication.dart';
import '../../domain/repositories/medication_repository.dart';
import '../../domain/services/medication_image_data.dart';
import 'add_reminder_page.dart';
import 'medication_report_page.dart';

typedef _MedicineReminderItem = ({
  Medication medication,
  MedicationDose dose,
  DateTime scheduledAt,
});

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
  List<Medication> _loadedMedications = const <Medication>[];
  StreamSubscription<String>? _automaticBackupSubscription;
  StreamSubscription<String>? _openedReminderSubscription;
  OverlayEntry? _foregroundReminderEntry;
  String? _lastForegroundReminderKey;
  String? _pendingOpenedReminderPayload;
  bool _checkedRecentReminderOnLoad = false;
  bool _manualBackupInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final now = DateTime.now();
        setState(() => _now = now);
        _showForegroundReminderIfDue(now);
      }
    });
    _automaticBackupSubscription = widget.repository.automaticBackupSucceeded
        .where((uid) => uid == widget.uid)
        .listen((_) {
          if (!mounted || _manualBackupInProgress) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('automatic_backup_complete'))),
          );
        });
    _openedReminderSubscription = widget.repository.openedReminderPayloads
        .listen(_handleOpenedReminderPayload);
    _pendingOpenedReminderPayload = widget.repository
        .takePendingOpenedReminderPayload();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoSync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _hideForegroundReminder();
    unawaited(_automaticBackupSubscription?.cancel());
    unawaited(_openedReminderSubscription?.cancel());
    unawaited(widget.repository.stopAutoSync());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_startAutoSync());
      _showForegroundReminderIfDue(DateTime.now(), includeRecent: true);
    }
  }

  Future<void> _startAutoSync() async {
    await widget.repository.startAutoSync(uid: widget.uid);
    if (mounted) {
      setState(_load);
    }
  }

  void _load() {
    _checkedRecentReminderOnLoad = false;
    _medicationsFuture = widget.repository.getAll(uid: widget.uid);
  }

  void _showForegroundReminderIfDue(
    DateTime now, {
    bool includeRecent = false,
  }) {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (!mounted ||
        (lifecycleState != null &&
            lifecycleState != AppLifecycleState.resumed)) {
      return;
    }
    final due = <_MedicineReminderItem>[];
    final seen = <String>{};
    for (final medication in _loadedMedications.where(
      (item) => item.isActive && item.occursOnDate(now),
    )) {
      for (final dose in medication.effectiveDoses) {
        final time = _parseDashboardTime(dose.timeOfDay);
        final scheduledAt = DateTime(
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );
        final elapsed = now.difference(scheduledAt);
        final isDueNow =
            elapsed >= Duration.zero && elapsed < const Duration(minutes: 1);
        final isRecentlyDue =
            includeRecent &&
            elapsed >= Duration.zero &&
            elapsed <= const Duration(minutes: 5);
        final checkIn = medication.checkInFor(
          scheduledAt,
          _canonicalTime(scheduledAt),
        );
        if ((isDueNow || isRecentlyDue) && checkIn?.medicineStatus == null) {
          final key = '${medication.id}|${dose.timeOfDay}';
          if (seen.add(key)) {
            due.add((
              medication: medication,
              dose: dose,
              scheduledAt: scheduledAt,
            ));
          }
        }
      }
    }
    if (due.isEmpty) {
      return;
    }

    final minuteKey =
        '${medicationDateKey(now)}|'
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    if (_lastForegroundReminderKey == minuteKey) {
      return;
    }
    _lastForegroundReminderKey = minuteKey;
    _showMedicineReminderOverlay(due);
  }

  void _showMedicineReminderOverlay(List<_MedicineReminderItem> items) {
    if (!mounted || items.isEmpty) {
      return;
    }
    _hideForegroundReminder();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    _foregroundReminderEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 220),
                      tween: Tween<double>(begin: 0.94, end: 1),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Transform.scale(
                        scale: value,
                        child: Opacity(opacity: value, child: child),
                      ),
                      child: _ForegroundMedicineReminderCard(
                        items: items,
                        onDismiss: _hideForegroundReminder,
                        onTaken: () {
                          _hideForegroundReminder();
                          unawaited(_recordReminderItems(items, taken: true));
                        },
                        onNotTaken: () {
                          _hideForegroundReminder();
                          unawaited(_recordReminderItems(items, taken: false));
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_foregroundReminderEntry!);
  }

  void _hideForegroundReminder() {
    _foregroundReminderEntry?.remove();
    _foregroundReminderEntry = null;
  }

  Future<void> _recordReminderItems(
    List<_MedicineReminderItem> items, {
    required bool taken,
  }) async {
    for (final item in items) {
      if (taken) {
        await _recordMedicineTaken(
          item.medication,
          item.scheduledAt,
          takenAt: DateTime.now(),
          reload: false,
        );
      } else {
        await _recordMedicineNotTaken(
          item.medication,
          item.scheduledAt,
          reload: false,
        );
      }
    }
    if (mounted) {
      setState(_load);
    }
  }

  void _handleOpenedReminderPayload(String payload) {
    widget.repository.takePendingOpenedReminderPayload();
    _pendingOpenedReminderPayload = payload;
    if (_loadedMedications.isNotEmpty) {
      _showPendingOpenedReminder();
    }
  }

  void _showPendingOpenedReminder() {
    final payload = _pendingOpenedReminderPayload;
    if (!mounted || payload == null || _loadedMedications.isEmpty) {
      return;
    }
    _pendingOpenedReminderPayload = null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final scheduledAt =
          DateTime.tryParse(decoded['scheduledAt']?.toString() ?? '') ??
          DateTime.now();
      final doses = decoded['doses'];
      if (doses is! List) {
        return;
      }
      final items = <_MedicineReminderItem>[];
      final seen = <String>{};
      for (final rawDose in doses) {
        if (rawDose is! Map) {
          continue;
        }
        final medicationId = rawDose['medicationId']?.toString();
        final doseTime = rawDose['doseTime']?.toString();
        Medication? medication;
        for (final candidate in _loadedMedications) {
          if (candidate.id == medicationId) {
            medication = candidate;
            break;
          }
        }
        if (medication == null || doseTime == null) {
          continue;
        }
        MedicationDose? dose;
        for (final candidate in medication.effectiveDoses) {
          if (candidate.timeOfDay == doseTime) {
            dose = candidate;
            break;
          }
        }
        if (dose == null || !seen.add('${medication.id}|$doseTime')) {
          continue;
        }
        final clock = _parseDashboardTime(doseTime);
        items.add((
          medication: medication,
          dose: dose,
          scheduledAt: DateTime(
            scheduledAt.year,
            scheduledAt.month,
            scheduledAt.day,
            clock.hour,
            clock.minute,
          ),
        ));
      }
      _showMedicineReminderOverlay(items);
    } catch (_) {
      return;
    }
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(_load);
    }
    await _medicationsFuture;
  }

  Future<void> _backup() async {
    _manualBackupInProgress = true;
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
    } finally {
      _manualBackupInProgress = false;
    }
  }

  String _canonicalTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveCheckIn(
    Medication medication,
    DateTime scheduledTime,
    MedicationCheckIn Function(MedicationCheckIn current) update, {
    bool reload = true,
  }) async {
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
    if (mounted && reload) {
      setState(_load);
    }
  }

  Future<void> _recordMedicineTaken(
    Medication medication,
    DateTime scheduledTime, {
    required DateTime takenAt,
    bool reload = true,
  }) {
    return _saveCheckIn(
      medication,
      scheduledTime,
      (current) => MedicationCheckIn(
        dateKey: current.dateKey,
        doseTime: current.doseTime,
        medicineStatus: 'taken',
        mealStatus: current.mealStatus,
        medicineTakenAt: takenAt,
        mealTakenAt: current.mealTakenAt,
        takenWithMeal: current.takenWithMeal,
      ),
      reload: reload,
    );
  }

  Future<void> _recordMedicineNotTaken(
    Medication medication,
    DateTime scheduledTime, {
    bool reload = true,
  }) {
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
      reload: reload,
    );
  }

  Future<void> _editConsumptionRecord(
    Medication medication,
    DateTime scheduledTime,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.medication_outlined),
                title: Text(context.tr('mark_taken')),
                onTap: () => Navigator.pop(sheetContext, 'medicineTaken'),
              ),
              ListTile(
                leading: const Icon(Icons.medication_outlined),
                title: Text(context.tr('mark_not_taken')),
                onTap: () => Navigator.pop(sheetContext, 'medicineNotTaken'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'medicineTaken':
        await _chooseTakenStatus(medication, scheduledTime);
        break;
      case 'medicineNotTaken':
        await _recordMedicineNotTaken(medication, scheduledTime);
        break;
    }
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
    if (choice == 'now') {
      await _recordMedicineTaken(
        medication,
        scheduledTime,
        takenAt: DateTime.now(),
      );
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: context.tr('choose_actual_time'),
      builder: buildEnglish12HourTimePicker,
    );
    if (!mounted || picked == null) {
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
    final totalSeconds = math.max(0, scheduledAt.difference(_now).inSeconds);
    final hours = totalSeconds ~/ Duration.secondsPerHour;
    final minutes = (totalSeconds ~/ Duration.secondsPerMinute) % 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}h '
        '${minutes.toString().padLeft(2, '0')}m '
        '${seconds.toString().padLeft(2, '0')}s';
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
            if (snapshot.hasData) {
              _loadedMedications = medications;
              if (_pendingOpenedReminderPayload != null ||
                  !_checkedRecentReminderOnLoad) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }
                  _showPendingOpenedReminder();
                  if (!_checkedRecentReminderOnLoad) {
                    _checkedRecentReminderOnLoad = true;
                    _showForegroundReminderIfDue(
                      DateTime.now(),
                      includeRecent: true,
                    );
                  }
                });
              }
            }
            final todayMedications = medications
                .where((medication) => medication.occursOnDate(_now))
                .toList(growable: false);
            final upcomingEvents = buildMedicationReminderPlan(
              medications,
              from: _now,
              horizonDays: 366,
              maxEvents: 3,
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
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
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
                            trackingTime: trackingTime,
                            now: _now,
                            checkIn: checkIn,
                            onMedicineTaken: () =>
                                _chooseTakenStatus(medication, trackingTime),
                            onMedicineNotTaken: () => _recordMedicineNotTaken(
                              medication,
                              trackingTime,
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
                value: formatEnglish12Hour(
                  _parseDashboardTime(medication.timeOfDay),
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
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _editConsumptionRecord(
                    medication,
                    _trackingTime(medication),
                  );
                },
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(context.tr('edit_consumption_record')),
              ),
              const SizedBox(height: 12),
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

class _ForegroundMedicineReminderCard extends StatelessWidget {
  const _ForegroundMedicineReminderCard({
    required this.items,
    required this.onDismiss,
    required this.onTaken,
    required this.onNotTaken,
  });

  final List<_MedicineReminderItem> items;
  final VoidCallback onDismiss;
  final VoidCallback onTaken;
  final VoidCallback onNotTaken;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('foreground-medicine-reminder'),
      color: Colors.white,
      elevation: 14,
      shadowColor: AppPalette.aubergine.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppPalette.plum.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppPalette.aubergine,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.medication_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    context.tr('reminder_medicine_title'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 49, right: 8),
              child: Text(
                context.tr('reminder_medicine_message'),
                style: const TextStyle(
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.min(280, items.length * 62).toDouble(),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: AppPalette.plum.withValues(alpha: 0.12),
                ),
                itemBuilder: (context, index) =>
                    _ForegroundMedicineRow(item: items[index]),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNotTaken,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(
                      context.tr('mark_not_taken'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onTaken,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      context.tr('mark_taken'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ForegroundMedicineRow extends StatelessWidget {
  const _ForegroundMedicineRow({required this.item});

  final _MedicineReminderItem item;

  @override
  Widget build(BuildContext context) {
    final value = item.dose.dosageValue.trim();
    final unit = switch (item.dose.dosageUnit) {
      'ml' => context.tr('ml'),
      'drop' => context.tr('drop_unit'),
      'unit' => context.tr('units'),
      _ => context.tr('pill'),
    };
    final details = <String>[
      if (value.isNotEmpty) '$value $unit',
      formatEnglish12Hour(_parseDashboardTime(item.dose.timeOfDay)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 9, color: AppPalette.persimmon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.medication.medicineName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  details.join(' • '),
                  style: const TextStyle(
                    color: AppPalette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.upcomingEvents,
    required this.countdownText,
    required this.now,
  });

  final List<MedicationReminderPlanItem> upcomingEvents;
  final String countdownText;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final nextEvent = upcomingEvents.isEmpty ? null : upcomingEvents.first;
    final arcEndEvent = _arcEndEvent(upcomingEvents, now);
    final arcEnd = arcEndEvent?.scheduledAt;
    final arcDuration = arcEnd?.difference(now);
    final arcEventFractions = arcEnd == null || arcDuration == null
        ? const <double>[]
        : upcomingEvents
              .where((event) => !event.scheduledAt.isAfter(arcEnd))
              .map((event) {
                if (arcDuration.inMilliseconds <= 0) {
                  return 1.0;
                }
                return event.scheduledAt.difference(now).inMilliseconds /
                    arcDuration.inMilliseconds;
              })
              .toList(growable: false);
    final headlineDate = nextEvent?.scheduledAt ?? now;
    final weekday = _localizedWeekday(context, headlineDate);
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
                          _OrdinalDateText(
                            date: headlineDate,
                            key: const ValueKey('hero-date'),
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
            height: 198,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DayCyclePainter(
                      eventFractions: arcEventFractions,
                    ),
                  ),
                ),
                Positioned(
                  left: 40,
                  right: 40,
                  top: nextEvent == null ? 88 : 74,
                  child: Column(
                    children: [
                      Text(
                        nextEvent == null
                            ? context.tr('no_active_medicines')
                            : _eventLabel(context, nextEvent),
                        key: const ValueKey('hero-current-event'),
                        maxLines: nextEvent == null ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: nextEvent == null ? 16 : 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (nextEvent != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          '${context.tr('due_in')} $countdownText',
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 4,
                  bottom: 0,
                  child: Text(
                    context.tr('now'),
                    key: const ValueKey('hero-now-time'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 0,
                  child: Text(
                    arcEnd == null ? '--' : _eventTime(context, arcEnd),
                    style: const TextStyle(
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
          key: ValueKey('upcoming-event-$index'),
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

MedicationReminderPlanItem? _arcEndEvent(
  List<MedicationReminderPlanItem> events,
  DateTime now,
) {
  if (events.isEmpty) {
    return null;
  }
  final first = events.first;
  if (events.length > 1 &&
      first.scheduledAt.difference(now) <= const Duration(minutes: 5)) {
    return events[1];
  }
  return first;
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
  const _DayCyclePainter({required this.eventFractions});

  final List<double> eventFractions;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = math.min(size.width - 32, (size.height - 58) * 2);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 34),
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
    canvas.drawArc(rect, math.pi, math.pi, false, progressPaint);

    for (final fraction in eventFractions.toSet()) {
      final safeFraction = fraction.clamp(0.0, 1.0);
      final point = _pointOnDayArc(rect, safeFraction);
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
        Paint()..color = AppPalette.aubergine.withValues(alpha: 0.72),
      );
    }

    final currentPoint = _pointOnDayArc(rect, 0);
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
    if (oldDelegate.eventFractions.length != eventFractions.length) {
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
        if (constraints.maxWidth < 500 && cards.length == 3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 12),
              cards[2],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              Expanded(child: cards[index]),
            ],
          ],
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
    final primary = FilledButton.icon(
      onPressed: onPrimary,
      icon: const Icon(Icons.add),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Text(primaryLabel, textAlign: TextAlign.center),
      ),
    );
    final secondary = OutlinedButton.icon(
      onPressed: onSecondary,
      icon: const Icon(Icons.cloud_upload_outlined),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Text(secondaryLabel, textAlign: TextAlign.center),
      ),
    );
    return Row(
      children: [
        Expanded(child: primary),
        const SizedBox(width: 10),
        Expanded(child: secondary),
      ],
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 104),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: AppPalette.persimmon),
              const SizedBox(height: 10),
              Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
    required this.trackingTime,
    required this.now,
    required this.checkIn,
    required this.onMedicineTaken,
    required this.onMedicineNotTaken,
    required this.onTap,
  });

  final Medication medication;
  final DateTime nextTime;
  final DateTime trackingTime;
  final DateTime now;
  final MedicationCheckIn? checkIn;
  final VoidCallback onMedicineTaken;
  final VoidCallback onMedicineNotTaken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final medicineRecorded = checkIn?.medicineStatus != null;
    final medicineActionAvailable = !now.isBefore(
      trackingTime.subtract(const Duration(minutes: 5)),
    );
    final showMedicineActions = !medicineRecorded && medicineActionAvailable;
    final nextLabel = formatEnglish12HourDateTime(nextTime);
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
              if (showMedicineActions) const SizedBox(height: 14),
              if (showMedicineActions)
                _StatusActions(
                  title: context.tr('medicine_status'),
                  status: checkIn?.medicineStatus,
                  takenAt: checkIn?.medicineTakenAt,
                  onTaken: onMedicineTaken,
                  onNotTaken: onMedicineNotTaken,
                ),
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
  });

  final String title;
  final String? status;
  final DateTime? takenAt;
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
        : '$statusText • ${formatEnglish12HourDateTime(takenAt!)}';

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
        final displayTime = formatEnglish12Hour(
          _parseDashboardTime(dose.timeOfDay),
        );
        return '$displayTime — ${dose.dosageValue} $unit';
      })
      .join(' • ');
}

String _eventLabel(BuildContext context, MedicationReminderPlanItem event) {
  return event.doses
      .map((item) => item.medication.medicineName)
      .toSet()
      .join(', ');
}

String _eventTime(BuildContext context, DateTime scheduledAt) {
  return formatEnglish12HourDateTime(scheduledAt);
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

class _OrdinalDateText extends StatelessWidget {
  const _OrdinalDateText({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Colors.white70,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.3,
    );
    final isBangla =
        AppLanguageScope.controllerOf(context).languageCode == 'bn';
    if (isBangla) {
      return Text(
        '${_toBanglaDigits(date.day)} '
        '${_banglaMonths[date.month - 1]}, ${_toBanglaDigits(date.year)}',
        style: style,
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${date.day}'),
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Transform.translate(
              offset: const Offset(0, -2),
              child: Text(
                _englishOrdinalSuffix(date.day),
                style: style.copyWith(fontSize: 9, height: 1),
              ),
            ),
          ),
          TextSpan(text: ' ${_englishMonths[date.month - 1]}, ${date.year}'),
        ],
      ),
      style: style,
    );
  }
}

const _englishMonths = <String>[
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

const _banglaMonths = <String>[
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

String _englishOrdinalSuffix(int day) {
  final mod100 = day % 100;
  if (mod100 >= 11 && mod100 <= 13) {
    return 'th';
  }
  return switch (day % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };
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
