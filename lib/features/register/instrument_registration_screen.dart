import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/f_hole.dart';
import '../../domain/models/device_info.dart';
import '../../domain/models/instrument.dart';
import '../pairing/pairing_controller.dart';

/// Collects the instrument profile and attaches it to the paired sensor.
class InstrumentRegistrationScreen extends StatefulWidget {
  const InstrumentRegistrationScreen({
    super.key,
    required this.sensor,
    required this.onBack,
    required this.onSave,
  });

  final DeviceInfo sensor;
  final VoidCallback onBack;
  final Future<void> Function(Instrument instrument, Uint8List? photoBytes)
  onSave;

  @override
  State<InstrumentRegistrationScreen> createState() =>
      _InstrumentRegistrationScreenState();
}

class _InstrumentRegistrationScreenState
    extends State<InstrumentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _year = TextEditingController();
  final _era = TextEditingController();
  final _maker = TextEditingController();
  final _origin = TextEditingController();
  final _topWood = TextEditingController(text: 'Spruce');
  final _backWood = TextEditingController(text: 'Maple');
  final _varnish = TextEditingController(text: 'Oil varnish');
  final _repairNote = TextEditingController();
  InstrumentType _type = InstrumentType.violin;
  Uint8List? _photoBytes;
  String? _photoName;
  bool _hasRepairs = false;
  bool _choosingPhoto = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    _era.dispose();
    _maker.dispose();
    _origin.dispose();
    _topWood.dispose();
    _backWood.dispose();
    _varnish.dispose();
    _repairNote.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    setState(() => _choosingPhoto = true);
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (!mounted || file == null) return;
      final length = await file.length();
      if (length != null && length > 8 * 1024 * 1024) {
        _message('Choose an image smaller than 8 MB.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        _message('That image could not be read. Try another photo.');
      } else if (bytes.lengthInBytes > 8 * 1024 * 1024) {
        _message('Choose an image smaller than 8 MB.');
      } else {
        setState(() {
          _photoBytes = bytes;
          _photoName = file.name;
        });
      }
    } on Object {
      if (mounted) {
        _message('The photo could not be opened. Try another image.');
      }
    } finally {
      if (mounted) setState(() => _choosingPhoto = false);
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final yearMade = int.parse(_year.text.trim());
    final name = _name.text.trim();
    setState(() => _saving = true);
    try {
      await widget.onSave(
        Instrument(
          id: _makeId(_type, name),
          name: name,
          type: _type,
          maker: _optional(_maker.text),
          origin: _optional(_origin.text),
          yearMade: yearMade,
          era: _optional(_era.text),
          topWood: _topWood.text.trim(),
          backWood: _backWood.text.trim(),
          varnish: _varnish.text.trim(),
          crackRepairs: _hasRepairs,
          crackRepairNote: _hasRepairs ? _optional(_repairNote.text) : null,
          sensorId: widget.sensor.id,
          sensorPublicKey: widget.sensor.publicKey,
        ),
        _photoBytes,
      );
    } on Object catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''));
        setState(() => _saving = false);
      }
    }
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Add $label to continue.' : null;

  String? _validateYear(String? value) {
    final year = int.tryParse(value?.trim() ?? '');
    if (year == null) return 'Enter an approximate year.';
    if (year < 1300 || year > DateTime.now().year) {
      return 'Use a year from 1300 to ${DateTime.now().year}.';
    }
    return null;
  }

  String _makeId(InstrumentType type, String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'(^-|-$)'), '');
    return 'registered-${type.name}-${slug.isEmpty ? 'instrument' : slug}';
  }

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to sensor',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Add to the collection'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.page,
            Space.m,
            Space.page,
            Space.xxxl,
          ),
          child: Center(
            child: SizedBox(
              width: width > 760 ? 680 : double.infinity,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Eyebrow('A record of care'),
                    const SizedBox(height: Space.s),
                    Text('Give it a name.', style: text.displayMedium),
                    const SizedBox(height: Space.s),
                    Text(
                      'Add what you know. Its signed condition history begins '
                      'with this sensor.',
                      style: text.bodyLarge!.copyWith(color: colors.textMuted),
                    ),
                    const SizedBox(height: Space.xl),
                    AelosCard(
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: colors.accent,
                          ),
                          const SizedBox(width: Space.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sensor linked', style: text.titleSmall),
                                const SizedBox(height: Space.xs),
                                Text(
                                  'Aelos-${widget.sensor.id} · ${widget.sensor.firmware}',
                                  style: text.bodySmall,
                                ),
                                const SizedBox(height: Space.xs),
                                Text(
                                  'Key ${keyFingerprint(widget.sensor.publicKey)}',
                                  style: text.labelSmall!.copyWith(
                                    color: colors.textMuted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    const Eyebrow('The instrument'),
                    const SizedBox(height: Space.m),
                    _field(
                      controller: _name,
                      label: 'Name in your collection',
                      hint: 'e.g. Mittenwald violin',
                      validator: (value) => _required(value, 'a name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: Space.m),
                    DropdownButtonFormField<InstrumentType>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: [
                        for (final type in InstrumentType.values)
                          DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                      ],
                      onChanged: (type) {
                        if (type != null) setState(() => _type = type);
                      },
                    ),
                    const SizedBox(height: Space.m),
                    _field(
                      controller: _year,
                      label: 'Approximate year made',
                      hint: 'e.g. 1890',
                      validator: _validateYear,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: Space.m),
                    _field(
                      controller: _era,
                      label: 'Era or date note (optional)',
                      hint: 'e.g. c. 1860',
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: Space.m),
                    _field(
                      controller: _maker,
                      label: 'Maker or workshop (optional)',
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: Space.m),
                    _field(
                      controller: _origin,
                      label: 'Place of making (optional)',
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: Space.xl),
                    const Eyebrow('Materials and care'),
                    const SizedBox(height: Space.m),
                    _field(
                      controller: _topWood,
                      label: 'Top wood',
                      validator: (value) => _required(value, 'the top wood'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: Space.m),
                    _field(
                      controller: _backWood,
                      label: 'Back wood',
                      validator: (value) => _required(value, 'the back wood'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: Space.m),
                    _field(
                      controller: _varnish,
                      label: 'Varnish',
                      validator: (value) => _required(value, 'the varnish'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: Space.s),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _hasRepairs,
                      title: const Text('Past crack repairs'),
                      subtitle: Text(
                        'This can change the instrument’s climate limits.',
                        style: text.bodySmall,
                      ),
                      onChanged: (value) => setState(() => _hasRepairs = value),
                    ),
                    if (_hasRepairs) ...[
                      const SizedBox(height: Space.s),
                      _field(
                        controller: _repairNote,
                        label: 'Repair note (optional)',
                        hint: 'What was repaired?',
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 3,
                      ),
                    ],
                    const SizedBox(height: Space.xl),
                    const Eyebrow('Photograph'),
                    const SizedBox(height: Space.m),
                    AelosCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 184,
                            width: double.infinity,
                            child: _photoBytes == null
                                ? ColoredBox(
                                    color: colors.surface,
                                    child: Center(
                                      child: FHole(
                                        height: 88,
                                        color: colors.accent.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                  )
                                : Image.memory(_photoBytes!, fit: BoxFit.cover),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(Space.m),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _photoName ??
                                        'Optional · kept on this device',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _choosingPhoto
                                      ? null
                                      : _choosePhoto,
                                  icon: _choosingPhoto
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.6,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.add_photo_alternate_outlined,
                                        ),
                                  label: Text(
                                    _photoBytes == null ? 'Choose' : 'Change',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_outlined),
                      label: Text(
                        _saving ? 'Creating record…' : 'Add to collection',
                      ),
                    ),
                    const SizedBox(height: Space.s),
                    Text(
                      'Your details and photograph stay in memory for this demo session.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall!.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
  }) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label, hintText: hint),
    validator: validator,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    maxLines: maxLines,
  );
}
