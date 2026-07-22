import 'package:flutter/material.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/medication_report.dart';
import '../../domain/repositories/medication_repository.dart';

class MedicationReportPage extends StatefulWidget {
  const MedicationReportPage({
    super.key,
    required this.uid,
    required this.repository,
  });

  final String uid;
  final MedicationRepository repository;

  @override
  State<MedicationReportPage> createState() => _MedicationReportPageState();
}

class _MedicationReportPageState extends State<MedicationReportPage> {
  int _rangeDays = 7;
  late Future<MedicationReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _reportFuture = widget.repository.getReport(
      uid: widget.uid,
      rangeDays: _rangeDays,
    );
  }

  Future<void> _refresh() async {
    setState(_load);
    await _reportFuture;
  }

  void _changeRange(int rangeDays) {
    if (_rangeDays == rangeDays) {
      return;
    }
    setState(() {
      _rangeDays = rangeDays;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('reports')),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LanguageToggleButton(),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<MedicationReport>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr('report_load_error'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final report = snapshot.data!;
          final groupedEntries = _groupEntries(report.entries);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 7,
                      label: Text(context.tr('last_7_days')),
                    ),
                    ButtonSegment(
                      value: 30,
                      label: Text(context.tr('last_30_days')),
                    ),
                  ],
                  selected: <int>{_rangeDays},
                  onSelectionChanged: (selection) =>
                      _changeRange(selection.first),
                ),
                const SizedBox(height: 14),
                _ReportPeriodCard(report: report),
                const SizedBox(height: 14),
                _ReportSummary(report: report),
                const SizedBox(height: 20),
                Text(
                  context.tr('report_details'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (groupedEntries.isEmpty)
                  const _EmptyReport()
                else
                  ...groupedEntries.entries.expand(
                    (group) => <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                        child: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatFullDate(group.value.first.scheduledAt),
                          style: const TextStyle(
                            color: AppPalette.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      ...group.value.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ReportEntryCard(entry: entry),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportPeriodCard extends StatelessWidget {
  const _ReportPeriodCard({required this.report});

  final MedicationReport report;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppPalette.aubergine,
            AppPalette.plum.withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range_outlined, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('report_period'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${localizations.formatMediumDate(report.periodStart)} — '
                  '${localizations.formatMediumDate(report.periodEnd)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${report.rangeDays}',
            style: const TextStyle(
              color: AppPalette.saffron,
              fontFamily: 'Manrope',
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.report});

  final MedicationReport report;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, int value, IconData icon, Color color})>[
      (
        label: context.tr('medicines_taken'),
        value: report.medicinesTaken,
        icon: Icons.medication_outlined,
        color: AppPalette.aubergine,
      ),
      (
        label: context.tr('medicines_not_taken'),
        value: report.medicinesNotTaken,
        icon: Icons.medication_liquid_outlined,
        color: AppPalette.persimmon,
      ),
      (
        label: context.tr('meals_taken'),
        value: report.mealsTaken,
        icon: Icons.restaurant_outlined,
        color: AppPalette.plum,
      ),
      (
        label: context.tr('meals_not_taken'),
        value: report.mealsNotTaken,
        icon: Icons.no_meals_outlined,
        color: AppPalette.saffron,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _ReportSummaryCard(
                    label: item.label,
                    value: item.value,
                    icon: item.icon,
                    color: item.color,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.plum.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(color: AppPalette.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ReportEntryCard extends StatelessWidget {
  const _ReportEntryCard({required this.entry});

  final MedicationReportEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheduledTime = _formatReportTime(context, entry.scheduledAt);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppPalette.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.plum.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.medicineName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                scheduledTime,
                style: const TextStyle(
                  color: AppPalette.muted,
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (entry.doseLabel.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              entry.doseLabel,
              style: const TextStyle(color: AppPalette.muted),
            ),
          ],
          const SizedBox(height: 12),
          _ReportStatusLine(
            icon: Icons.medication_outlined,
            label: context.tr('medicine_status'),
            status: entry.medicineStatus,
            recordedAt: entry.medicineTakenAt,
            suffix: entry.takenWithMeal ? context.tr('with_food') : null,
          ),
          if (entry.mealStatus != null || entry.mealTakenAt != null) ...[
            const SizedBox(height: 8),
            _ReportStatusLine(
              icon: Icons.restaurant_outlined,
              label: context.tr('meal_status'),
              status: entry.mealStatus,
              recordedAt: entry.mealTakenAt,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportStatusLine extends StatelessWidget {
  const _ReportStatusLine({
    required this.icon,
    required this.label,
    required this.status,
    required this.recordedAt,
    this.suffix,
  });

  final IconData icon;
  final String label;
  final String? status;
  final DateTime? recordedAt;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final isTaken = status == 'taken';
    final statusLabel = isTaken
        ? context.tr('status_taken')
        : status == 'notTaken'
        ? context.tr('status_not_taken')
        : context.tr('status_pending');
    final details = <String>[
      statusLabel,
      if (recordedAt != null) _formatReportDateTime(context, recordedAt!),
      if (suffix != null) suffix!,
    ].join(' • ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isTaken ? AppPalette.aubergine : AppPalette.persimmon,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: details),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppPalette.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppPalette.plum.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.fact_check_outlined,
            size: 38,
            color: AppPalette.persimmon,
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('no_report_entries'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            context.tr('report_range_hint'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppPalette.muted),
          ),
        ],
      ),
    );
  }
}

Map<String, List<MedicationReportEntry>> _groupEntries(
  List<MedicationReportEntry> entries,
) {
  final groups = <String, List<MedicationReportEntry>>{};
  for (final entry in entries) {
    final date = entry.scheduledAt;
    final key = '${date.year}-${date.month}-${date.day}';
    groups.putIfAbsent(key, () => <MedicationReportEntry>[]).add(entry);
  }
  return groups;
}

String _formatReportTime(BuildContext context, DateTime value) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(value),
    alwaysUse24HourFormat: false,
  );
}

String _formatReportDateTime(BuildContext context, DateTime value) {
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatMediumDate(value)} '
      '${_formatReportTime(context, value)}';
}
