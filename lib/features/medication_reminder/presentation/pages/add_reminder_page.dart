import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models/medication.dart';
import '../../domain/repositories/medication_repository.dart';

class AddReminderPage extends StatefulWidget {
  const AddReminderPage({
    super.key,
    required this.repository,
    required this.uid,
    required this.onSignOut,
    this.existingMedication,
  });

  final MedicationRepository repository;
  final String uid;
  final Future<void> Function() onSignOut;
  final Medication? existingMedication;

  @override
  State<AddReminderPage> createState() => _AddReminderPageState();
}

class _AddReminderPageState extends State<AddReminderPage> {
  final _medicineController = TextEditingController();
  final _formulaController = TextEditingController();
  final _companyController = TextEditingController();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();

  TimeOfDay _selectedTime = TimeOfDay.now();
  int _mealOffset = 0;
  bool _isActive = true;
  bool _busy = false;
  Uint8List? _imageBytes;
  String? _imagePath;
  late List<_DoseRow> _doseRows;

  @override
  void initState() {
    super.initState();
    final medication = widget.existingMedication;
    _doseRows = [_DoseRow()];
    if (medication != null) {
      _medicineController.text = medication.medicineName;
      _formulaController.text = medication.formula ?? '';
      _companyController.text = medication.companyName ?? '';
      _notesController.text = medication.notes ?? '';
      _mealOffset = medication.mealOffset;
      _isActive = medication.isActive;
      _imagePath = medication.imagePath;
      _selectedTime = _parseTime(medication.timeOfDay);
      _doseRows = _parseDoseRows(medication.dose);
    }
  }

  @override
  void dispose() {
    _medicineController.dispose();
    _formulaController.dispose();
    _companyController.dispose();
    _notesController.dispose();
    for (final row in _doseRows) {
      row.dispose();
    }
    super.dispose();
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

  List<_DoseRow> _parseDoseRows(String doseText) {
    if (doseText.trim().isEmpty) {
      return [_DoseRow()];
    }
    return doseText
        .split(' • ')
        .map((part) => _DoseRow.fromSummary(part))
        .toList();
  }

  String _canonicalTime(TimeOfDay timeOfDay) {
    return '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: 'Choose reminder time',
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
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
      _doseRows.add(_DoseRow());
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

  String _composeDoseSummary() {
    final rows = _doseRows
        .map((row) => row.summary)
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
    return rows.join(' • ');
  }

  Future<void> _saveReminder() async {
    if (_medicineController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the medicine name.')),
      );
      return;
    }

    final doseSummary = _composeDoseSummary();
    if (doseSummary.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one dose line.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final existing = widget.existingMedication;
      final medication = Medication(
        id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
        medicineName: _medicineController.text.trim(),
        formula: _formulaController.text.trim().isEmpty
            ? null
            : _formulaController.text.trim(),
        companyName: _companyController.text.trim().isEmpty
            ? null
            : _companyController.text.trim(),
        imagePath: _imagePath ?? existing?.imagePath,
        imageBytesBase64: _imageBytes == null
            ? existing?.imageBytesBase64
            : base64Encode(_imageBytes!),
        dose: doseSummary,
        durationDays: 0,
        timeOfDay: _canonicalTime(_selectedTime),
        mealOffset: _mealOffset,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        isActive: _isActive,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingMedication != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Medicine' : 'Add Medicine'),
        actions: [
          TextButton(
            onPressed: widget.onSignOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeaderCard(
              title: isEditing
                  ? 'Update medicine details'
                  : 'Create a medicine reminder',
              subtitle:
                  'Keep the form simple, but let each dose be entered as a clear structured line.',
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Medicine details',
              child: Column(
                children: [
                  TextField(
                    controller: _medicineController,
                    decoration: const InputDecoration(
                      labelText: 'Medicine name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _formulaController,
                    decoration: const InputDecoration(
                      labelText: 'Formula (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _companyController,
                    decoration: const InputDecoration(
                      labelText: 'Company name (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Dosage builder',
              trailing: TextButton.icon(
                onPressed: _addDoseRow,
                icon: const Icon(Icons.add),
                label: const Text('Add dose line'),
              ),
              child: Column(
                children: [
                  ...List.generate(_doseRows.length, (index) {
                    final row = _doseRows[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _doseRows.length - 1 ? 0 : 12,
                      ),
                      child: _DoseRowEditor(
                        row: row,
                        index: index,
                        canRemove: _doseRows.length > 1,
                        onChanged: () => setState(() {}),
                        onRemove: () => _removeDoseRow(index),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preview',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _composeDoseSummary().isEmpty
                              ? 'Dose summary will appear here.'
                              : _composeDoseSummary(),
                          style: const TextStyle(fontSize: 15, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Schedule & photo',
              child: Column(
                children: [
                  Semantics(
                    button: true,
                    label: 'Pick medicine reminder time',
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        'Reminder time: ${_selectedTime.format(context)}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _mealOffset,
                    decoration: const InputDecoration(
                      labelText: 'Meal offset',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: -30,
                        child: Text('30 min before meal'),
                      ),
                      DropdownMenuItem(value: 0, child: Text('At meal time')),
                      DropdownMenuItem(
                        value: 30,
                        child: Text('30 min after meal'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _mealOffset = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Photo',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_imageBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.memory(
                                _imageBytes!,
                                height: 180,
                                fit: BoxFit.cover,
                              ),
                            )
                          else if ((_imagePath ?? '').isNotEmpty)
                            Container(
                              height: 180,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text('Photo saved locally'),
                            )
                          else
                            Container(
                              height: 180,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text('No photo selected'),
                            ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: _pickPhoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Take photo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _isActive,
              title: const Text('Active reminder'),
              subtitle: const Text('Keep this medicine scheduled and notified'),
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: isEditing ? 'Update medicine' : 'Save medicine',
              child: FilledButton(
                onPressed: _busy ? null : _saveReminder,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(isEditing ? 'Update Medicine' : 'Save Medicine'),
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
  const _HeaderCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
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
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
  _DoseRow() {
    amountController = TextEditingController();
    unit = _doseUnits.first;
    timing = _doseTimings.first;
    frequency = _doseFrequencies.first;
  }

  _DoseRow.fromSummary(String summary) {
    amountController = TextEditingController(text: summary);
    unit = _doseUnits.first;
    timing = _doseTimings.first;
    frequency = _doseFrequencies.first;
  }

  late final TextEditingController amountController;
  late String unit;
  late String timing;
  late String frequency;

  String get summary {
    final amount = amountController.text.trim();
    if (amount.isEmpty) {
      return '';
    }
    return [
      amount,
      unit,
      timing,
      frequency,
    ].where((value) => value.trim().isNotEmpty).join(' ').trim();
  }

  void dispose() {
    amountController.dispose();
  }
}

class _DoseRowEditor extends StatefulWidget {
  const _DoseRowEditor({
    required this.row,
    required this.index,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final _DoseRow row;
  final int index;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_DoseRowEditor> createState() => _DoseRowEditorState();
}

class _DoseRowEditorState extends State<_DoseRowEditor> {
  @override
  void initState() {
    super.initState();
    widget.row.amountController.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.row.amountController.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF0F766E),
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Dose line',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.canRemove)
                  IconButton(
                    tooltip: 'Remove dose line',
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: widget.row.amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ChoiceChipField(
                  label: 'Unit',
                  value: widget.row.unit,
                  options: _doseUnits,
                  onSelected: (value) => setState(() {
                    widget.row.unit = value;
                    widget.onChanged();
                  }),
                ),
                _ChoiceChipField(
                  label: 'When',
                  value: widget.row.timing,
                  options: _doseTimings,
                  onSelected: (value) => setState(() {
                    widget.row.timing = value;
                    widget.onChanged();
                  }),
                ),
                _ChoiceChipField(
                  label: 'Frequency',
                  value: widget.row.frequency,
                  options: _doseFrequencies,
                  onSelected: (value) => setState(() {
                    widget.row.frequency = value;
                    widget.onChanged();
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChipField extends StatelessWidget {
  const _ChoiceChipField({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map(
              (option) =>
                  DropdownMenuItem<String>(value: option, child: Text(option)),
            )
            .toList(growable: false),
        onChanged: (selected) {
          if (selected != null) {
            onSelected(selected);
          }
        },
      ),
    );
  }
}

const List<String> _doseUnits = <String>[
  'tablet',
  'capsule',
  'syrup',
  'ml',
  'drop',
  'sachet',
  'spoon',
];

const List<String> _doseTimings = <String>[
  'before meal',
  'after meal',
  'morning',
  'noon',
  'night',
  'bedtime',
];

const List<String> _doseFrequencies = <String>[
  'once',
  'twice',
  'three times',
  'four times',
  'as needed',
];
