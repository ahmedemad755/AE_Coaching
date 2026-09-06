import 'dart:io';

import 'package:ae_coaching/auth/data/models/body_measurement.dart';
import 'package:ae_coaching/features/measurements/presentation/cubit/measurement_cubit.dart';
import 'package:ae_coaching/features/measurements/presentation/widgets/measurement_avatar.dart';
import 'package:ae_coaching/features/measurements/presentation/widgets/measurement_field_defs.dart';
import 'package:ae_coaching/features/progress_photos/presentation/cubit/progress_photo_cubit.dart';
import 'package:ae_coaching/features/progress_photos/presentation/widgets/add_photo_preview_dialog.dart';
import 'package:ae_coaching/features/progress_photos/presentation/widgets/photo_source_sheet.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// Add or edit a single body measurement check-in.
///
/// Pass [existing] to edit a previously saved check-in (its date and
/// Hive key are preserved); omit it to record a brand new check-in
/// dated `DateTime.now()`. Every field is optional, but at least one
/// value is required to save.
class AddEditMeasurementScreen extends StatefulWidget {
  final BodyMeasurement? existing;

  const AddEditMeasurementScreen({super.key, this.existing});

  @override
  State<AddEditMeasurementScreen> createState() =>
      _AddEditMeasurementScreenState();
}

class _AddEditMeasurementScreenState extends State<AddEditMeasurementScreen> {
  static const Color _blue = Color(0xff2f80ed);
  static const Color _muted = Color(0xff7d8792);

  late final TextEditingController _chestCtrl;
  late final TextEditingController _waistCtrl;
  late final TextEditingController _hipsCtrl;
  late final TextEditingController _shouldersCtrl;
  late final TextEditingController _neckCtrl;
  late final TextEditingController _rightArmCtrl;
  late final TextEditingController _leftArmCtrl;
  late final TextEditingController _rightThighCtrl;
  late final TextEditingController _leftThighCtrl;
  late final TextEditingController _rightCalfCtrl;
  late final TextEditingController _leftCalfCtrl;

  bool get _isEditing => widget.existing != null;

  late final Map<String, MeasurementFieldDef> _defsByKey = {
    for (final def in measurementFieldDefs) def.key: def,
  };

  // Editable check-in date. Defaults to today for a new check-in, or the
  // stored date when editing — but the user can change it (e.g. to
  // back-date a check-in, or to quickly generate test data on different
  // days without waiting for real time to pass).
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.existing?.date ?? DateTime.now();
    final m = widget.existing;
    _chestCtrl = TextEditingController(text: _initialText(m?.chest));
    _waistCtrl = TextEditingController(text: _initialText(m?.waist));
    _hipsCtrl = TextEditingController(text: _initialText(m?.hips));
    _shouldersCtrl = TextEditingController(text: _initialText(m?.shoulders));
    _neckCtrl = TextEditingController(text: _initialText(m?.neck));
    _rightArmCtrl = TextEditingController(text: _initialText(m?.rightArm));
    _leftArmCtrl = TextEditingController(text: _initialText(m?.leftArm));
    _rightThighCtrl =
        TextEditingController(text: _initialText(m?.rightThigh));
    _leftThighCtrl = TextEditingController(text: _initialText(m?.leftThigh));
    _rightCalfCtrl = TextEditingController(text: _initialText(m?.rightCalf));
    _leftCalfCtrl = TextEditingController(text: _initialText(m?.leftCalf));
  }

  String _initialText(double? value) => value == null ? '' : value.toString();

  @override
  void dispose() {
    _chestCtrl.dispose();
    _waistCtrl.dispose();
    _hipsCtrl.dispose();
    _shouldersCtrl.dispose();
    _neckCtrl.dispose();
    _rightArmCtrl.dispose();
    _leftArmCtrl.dispose();
    _rightThighCtrl.dispose();
    _leftThighCtrl.dispose();
    _rightCalfCtrl.dispose();
    _leftCalfCtrl.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) => double.tryParse(c.text.trim());

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      // Wide range on purpose: lets you back-date real check-ins and
      // also fabricate future-dated test check-ins to verify analytics
      // without waiting for real days to pass.
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: _blue),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    final chest = _parse(_chestCtrl);
    final waist = _parse(_waistCtrl);
    final hips = _parse(_hipsCtrl);
    final shoulders = _parse(_shouldersCtrl);
    final neck = _parse(_neckCtrl);
    final rightArm = _parse(_rightArmCtrl);
    final leftArm = _parse(_leftArmCtrl);
    final rightThigh = _parse(_rightThighCtrl);
    final leftThigh = _parse(_leftThighCtrl);
    final rightCalf = _parse(_rightCalfCtrl);
    final leftCalf = _parse(_leftCalfCtrl);

    final hasAnyValue = [
      chest,
      waist,
      hips,
      shoulders,
      neck,
      rightArm,
      leftArm,
      rightThigh,
      leftThigh,
      rightCalf,
      leftCalf,
    ].any((v) => v != null);

    if (!hasAnyValue) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.enterAtLeastOneMeasurement),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final measurement = BodyMeasurement(
      date: _selectedDate,
      chest: chest,
      waist: waist,
      hips: hips,
      shoulders: shoulders,
      neck: neck,
      rightArm: rightArm,
      leftArm: leftArm,
      rightThigh: rightThigh,
      leftThigh: leftThigh,
      rightCalf: rightCalf,
      leftCalf: leftCalf,
    );

    final cubit = context.read<MeasurementCubit>();
    if (_isEditing) {
      cubit.updateMeasurement(widget.existing!.key, measurement);
      if (mounted) Navigator.pop(context);
      return;
    }

    cubit.addMeasurement(measurement);

    // New check-in only (never on edit): offer to attach a progress
    // photo dated the same as this check-in.
    final l10n = AppLocalizations.of(context)!;
    final wantsPhoto = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xfff5f9fc),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          l10n.addPhotoPromptTitle,
          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xff202936)),
        ),
        content: Text(l10n.addPhotoPromptBody, style: const TextStyle(color: _muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.skip, style: const TextStyle(color: _blue)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
            child: Text(l10n.addPhotoButton),
          ),
        ],
      ),
    );

    if (wantsPhoto == true && mounted) {
      await _addProgressPhotoFor(_selectedDate);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _addProgressPhotoFor(DateTime date) async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;

    final XFile? picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    final confirmedDate = await showDialog<DateTime>(
      context: context,
      builder: (_) => AddPhotoPreviewDialog(imageFile: File(picked.path), initialDate: date),
    );

    if (confirmedDate != null && mounted) {
      context.read<ProgressPhotoCubit>().addPhoto(sourceFile: File(picked.path), date: confirmedDate);
    }
  }

  InputDecoration _decoration(AppLocalizations l10n, MeasurementFieldDef def) {
    return InputDecoration(
      labelText: def.localizedLabel(l10n),
      suffixText: l10n.cmUnit,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Padding(
        padding: const EdgeInsets.all(10),
        child: MeasurementAvatar(imagePath: def.imagePath, size: 24),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffd5e3f2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _blue),
      ),
    );
  }

  Widget _field(AppLocalizations l10n, MeasurementFieldDef def, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: _decoration(l10n, def),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}\.?\d{0,2}')),
      ],
    );
  }

  Widget _pairRow(
    AppLocalizations l10n,
    String keyA,
    TextEditingController ctrlA,
    String keyB,
    TextEditingController ctrlB,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(child: _field(l10n, _defsByKey[keyA]!, ctrlA)),
          const SizedBox(width: 12),
          Expanded(child: _field(l10n, _defsByKey[keyB]!, ctrlB)),
        ],
      ),
    );
  }

  Widget _singleField(AppLocalizations l10n, String key, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _field(l10n, _defsByKey[key]!, ctrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateLocale = Localizations.localeOf(context).toString();
    return Scaffold(
      backgroundColor: const Color(0xfff5f9fc),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: Text(_isEditing ? l10n.editMeasurementTitle : l10n.addMeasurementTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffd5e3f2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event, color: _blue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, d MMM yyyy', dateLocale).format(_selectedDate),
                        style: const TextStyle(
                          color: Color(0xff202936),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      l10n.changeDateButton,
                      style: const TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.allFieldsOptionalHint,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            _singleField(l10n, 'chest', _chestCtrl),
            _singleField(l10n, 'waist', _waistCtrl),
            _singleField(l10n, 'hips', _hipsCtrl),
            _singleField(l10n, 'shoulders', _shouldersCtrl),
            _singleField(l10n, 'neck', _neckCtrl),
            _pairRow(l10n, 'rightArm', _rightArmCtrl, 'leftArm', _leftArmCtrl),
            _pairRow(
                l10n, 'rightThigh', _rightThighCtrl, 'leftThigh', _leftThighCtrl),
            _pairRow(l10n, 'rightCalf', _rightCalfCtrl, 'leftCalf', _leftCalfCtrl),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 6,
              ),
              child: Text(
                _isEditing ? l10n.updateCheckInButton : l10n.saveCheckInButton,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
