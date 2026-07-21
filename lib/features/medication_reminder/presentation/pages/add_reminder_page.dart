import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/medication.dart';
import '../../domain/repositories/medication_repository.dart';

class AddReminderPage extends StatefulWidget {
  const AddReminderPage({
    super.key,
    required this.repository,
    required this.uid,
    this.existingMedication,
  });

  final MedicationRepository repository;
  final String uid;
  final Medication? existingMedication;

  @override
  State<AddReminderPage> createState() => _AddReminderPageState();
}

class _AddReminderPageState extends State<AddReminderPage> {
  final _medicineController = TextEditingController();
  final _powerController = TextEditingController();
  final _formulaController = TextEditingController();
  final _companyController = TextEditingController();
  final _notesController = TextEditingController();
  final _mealMinutesController = TextEditingController(text: '20');
  final _imagePicker = ImagePicker();

  String _medicineType = 'tablet';
  String _powerUnit = 'mg';
  String _mealRelation = 'before';
  bool _mealScheduleEnabled = false;
  bool _busy = false;
  Uint8List? _imageBytes;
  String? _imagePath;
  late List<_DoseRow> _doseRows;

  @override
  void initState() {
    super.initState();
    final medication = widget.existingMedication;
    _doseRows = <_DoseRow>[_DoseRow(time: TimeOfDay.now())];
    if (medication != null) {
      _medicineController.text = medication.medicineName;
      _powerController.text = medication.powerValue ?? '';
      _formulaController.text = medication.formula ?? '';
      _companyController.text = medication.companyName ?? '';
      _notesController.text = medication.notes ?? '';
      _medicineType = _medicineTypes.contains(medication.medicineType)
          ? medication.medicineType
          : 'tablet';
      _powerUnit = _powerUnits.contains(medication.powerUnit)
          ? medication.powerUnit
          : 'mg';
      if (medication.mealOffset < 0) {
        _mealRelation = 'before';
        _mealMinutesController.text = medication.mealOffset.abs().toString();
      } else if (medication.mealOffset > 0) {
        _mealRelation = 'after';
        _mealMinutesController.text = medication.mealOffset.toString();
      } else {
        _mealRelation = 'with';
      }
      _mealScheduleEnabled = medication.mealScheduleEnabled;
      _imagePath = medication.imagePath;
      _doseRows = _rowsFromMedication(medication);
    }
  }

  @override
  void dispose() {
    _medicineController.dispose();
    _powerController.dispose();
    _formulaController.dispose();
    _companyController.dispose();
    _notesController.dispose();
    _mealMinutesController.dispose();
    for (final row in _doseRows) {
      row.dispose();
    }
    super.dispose();
  }

  List<_DoseRow> _rowsFromMedication(Medication medication) {
    final doses = medication.effectiveDoses;
    if (doses.isEmpty) {
      return <_DoseRow>[_DoseRow(time: _parseTime(medication.timeOfDay))];
    }
    return doses
        .map(
          (dose) => _DoseRow(
            time: _parseTime(dose.timeOfDay),
            dosage: dose.dosageValue,
          ),
        )
        .toList(growable: true);
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return TimeOfDay.now();
    }
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? TimeOfDay.now().hour,
      minute: int.tryParse(parts[1]) ?? TimeOfDay.now().minute,
    );
  }

  String _canonicalTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  String _displayTime(TimeOfDay time) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(time, alwaysUse24HourFormat: false);
  }

  String get _dosageUnit {
    return switch (_medicineType) {
      'syrup' => 'ml',
      'drop' => 'drop',
      'insulin' => 'unit',
      _ => 'pill',
    };
  }

  int get _mealOffset {
    final enteredMinutes = int.tryParse(_mealMinutesController.text.trim());
    final minutes = (enteredMinutes == null || enteredMinutes <= 0)
        ? 20
        : enteredMinutes.clamp(1, 720);
    return switch (_mealRelation) {
      'before' => -minutes,
      'after' => minutes,
      _ => 0,
    };
  }

  String _localizedDosageUnit(BuildContext context) {
    return switch (_dosageUnit) {
      'ml' => context.tr('ml'),
      'drop' => context.tr('drop_unit'),
      'unit' => context.tr('units'),
      _ => context.tr('pill'),
    };
  }

  TimeOfDay _mealTimeFor(TimeOfDay medicineTime) {
    return _parseTime(
      calculateMealTime(_canonicalTime(medicineTime), _mealOffset),
    );
  }

  Future<void> _pickDoseTime(_DoseRow row) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: row.time,
      helpText: context.tr('choose_reminder_time'),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => row.time = picked);
    }
  }

  Future<void> _pickPhoto() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null) {
      return;
    }
    final bytes = await image.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imagePath = image.path;
    });
  }

  void _addDoseRow() {
    setState(() {
      _doseRows.add(_DoseRow(time: _doseRows.last.time));
    });
  }

  void _removeDoseRow(int index) {
    if (_doseRows.length == 1) {
      return;
    }
    setState(() {
      _doseRows[index].dispose();
      _doseRows.removeAt(index);
    });
  }

  List<MedicationDose> _structuredDoses() {
    return _doseRows
        .where((row) => row.dosageController.text.trim().isNotEmpty)
        .map(
          (row) => MedicationDose(
            timeOfDay: _canonicalTime(row.time),
            dosageValue: row.dosageController.text.trim(),
            dosageUnit: _dosageUnit,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _saveReminder() async {
    if (_medicineController.text.trim().isEmpty) {
      _showMessage(context.tr('medicine_name_required_error'));
      return;
    }
    if (_powerController.text.trim().isEmpty) {
      _showMessage(context.tr('power_required_error'));
      return;
    }
    final doses = _structuredDoses();
    if (doses.length != _doseRows.length) {
      _showMessage(context.tr('dose_line_required_error'));
      return;
    }

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final existing = widget.existingMedication;
      final doseSummary = doses.map((dose) => dose.summary).join(' • ');
      final medication = Medication(
        id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
        medicineName: _medicineController.text.trim(),
        medicineType: _medicineType,
        powerValue: _powerController.text.trim(),
        powerUnit: _powerUnit,
        languageCode: AppLanguageScope.controllerOf(context).languageCode,
        formula: _emptyToNull(_formulaController.text),
        companyName: _emptyToNull(_companyController.text),
        imagePath: _imagePath ?? existing?.imagePath,
        imageBytesBase64: _imageBytes == null
            ? existing?.imageBytesBase64
            : base64Encode(_imageBytes!),
        backupImageUrl: existing?.backupImageUrl,
        dose: doseSummary,
        doses: doses,
        doseTimes: doses.map((dose) => dose.timeOfDay).toList(growable: false),
        durationDays: 0,
        timeOfDay: doses.first.timeOfDay,
        mealOffset: _mealOffset,
        mealScheduleEnabled: _mealScheduleEnabled,
        mealTimes: _mealScheduleEnabled
            ? _doseRows
                  .map((row) => _canonicalTime(_mealTimeFor(row.time)))
                  .toList(growable: false)
            : const <String>[],
        checkIns: existing?.checkIns ?? const <MedicationCheckIn>[],
        notes: _emptyToNull(_notesController.text),
        isActive: true,
        updatedAt: now,
      );

      if (existing == null) {
        await widget.repository.add(uid: widget.uid, medication: medication);
      } else {
        await widget.repository.update(uid: widget.uid, medication: medication);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingMedication != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(isEditing ? 'edit_medicine' : 'add_medicine')),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: LanguageToggleButton(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeaderCard(
              title: context.tr(
                isEditing
                    ? 'update_medicine_details'
                    : 'create_medicine_reminder',
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: context.tr('medicine_details'),
              child: Column(
                children: [
                  TextField(
                    controller: _medicineController,
                    decoration: InputDecoration(
                      labelText: context.tr('medicine_name_required'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _medicineType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.tr('medicine_type'),
                      border: const OutlineInputBorder(),
                    ),
                    items: _medicineTypes
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(context.tr(type)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _medicineType = value;
                          if (value == 'insulin') {
                            _powerUnit = 'units/ml';
                          } else if (_powerUnit == 'units/ml') {
                            _powerUnit = 'mg';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final valueField = TextField(
                        controller: _powerController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.tr('power_value'),
                          border: const OutlineInputBorder(),
                        ),
                      );
                      final unitField = DropdownButtonFormField<String>(
                        key: ValueKey<String>('power-unit-$_medicineType'),
                        initialValue: _powerUnit,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.tr('power_unit'),
                          border: const OutlineInputBorder(),
                        ),
                        items: _powerUnits
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _powerUnit = value);
                          }
                        },
                      );
                      if (constraints.maxWidth < 360) {
                        return Column(
                          children: [
                            valueField,
                            const SizedBox(height: 12),
                            unitField,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: valueField),
                          const SizedBox(width: 12),
                          Expanded(child: unitField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _formulaController,
                    decoration: InputDecoration(
                      labelText: context.tr('formula_optional'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _companyController,
                    decoration: InputDecoration(
                      labelText: context.tr('company_optional'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.tr('notes_optional'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: context.tr('dosage_builder'),
              trailing: TextButton.icon(
                onPressed: _addDoseRow,
                icon: const Icon(Icons.add),
                label: Text(context.tr('add_dose_line')),
              ),
              child: Column(
                children: List.generate(_doseRows.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _doseRows.length - 1 ? 0 : 12,
                    ),
                    child: _DoseRowEditor(
                      row: _doseRows[index],
                      index: index,
                      dosageUnit: _localizedDosageUnit(context),
                      canRemove: _doseRows.length > 1,
                      onPickTime: () => _pickDoseTime(_doseRows[index]),
                      onRemove: () => _removeDoseRow(index),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: context.tr('meal_schedule'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _mealScheduleEnabled,
                    title: Text(context.tr('meal_schedule_enabled')),
                    subtitle: Text(context.tr('meal_schedule_help')),
                    onChanged: (value) {
                      setState(() => _mealScheduleEnabled = value);
                    },
                  ),
                  if (_mealScheduleEnabled) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _mealRelation,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr('meal_relation'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'before',
                          child: Text(context.tr('before_meal_custom')),
                        ),
                        DropdownMenuItem(
                          value: 'with',
                          child: Text(context.tr('at_meal')),
                        ),
                        DropdownMenuItem(
                          value: 'after',
                          child: Text(context.tr('after_meal_custom')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _mealRelation = value);
                        }
                      },
                    ),
                    if (_mealRelation != 'with') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _mealMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.tr('custom_meal_minutes'),
                          suffixText: context.tr('minutes_short'),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      context.tr('calculated_meal_times'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ..._doseRows.map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${context.tr('medicine_at')} '
                          '${_displayTime(row.time)} → '
                          '${context.tr('meal_at')} '
                          '${_displayTime(_mealTimeFor(row.time))}',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: context.tr('photo'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_imageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        _imageBytes!,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 150,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppPalette.blush.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        (_imagePath ?? '').isNotEmpty
                            ? context.tr('photo_saved_locally')
                            : context.tr('no_photo_selected'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(context.tr('take_photo')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _saveReminder,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  context.tr(isEditing ? 'update_medicine' : 'save_medicine'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.aubergine, AppPalette.persimmon],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppPalette.plum.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DoseRow {
  _DoseRow({required this.time, String dosage = ''})
    : dosageController = TextEditingController(text: dosage);

  TimeOfDay time;
  final TextEditingController dosageController;

  void dispose() => dosageController.dispose();
}

class _DoseRowEditor extends StatelessWidget {
  const _DoseRowEditor({
    required this.row,
    required this.index,
    required this.dosageUnit,
    required this.canRemove,
    required this.onPickTime,
    required this.onRemove,
  });

  final _DoseRow row;
  final int index;
  final String dosageUnit;
  final bool canRemove;
  final VoidCallback onPickTime;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppPalette.blush.withValues(alpha: 0.24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppPalette.plum.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppPalette.persimmon,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('dose_line'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (canRemove)
                  IconButton(
                    tooltip: context.tr('remove_dose_line'),
                    onPressed: onRemove,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final timeButton = SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: onPickTime,
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatTimeOfDay(row.time, alwaysUse24HourFormat: false),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                );
                final dosageField = TextField(
                  controller: row.dosageController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.tr('dosage_value'),
                    suffixText: dosageUnit,
                    border: const OutlineInputBorder(),
                  ),
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: timeButton),
                    const SizedBox(width: 10),
                    Expanded(flex: 6, child: dosageField),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

const List<String> _medicineTypes = <String>[
  'tablet',
  'capsule',
  'syrup',
  'drop',
  'insulin',
];

const List<String> _powerUnits = <String>['mg', 'g', 'mcg', 'units/ml'];
