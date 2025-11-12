import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/profile_controller.dart';
import '../../../widgets/toast.dart';
import 'package:antroph_mobile/widgets/app_input.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  DateTime? _dob;
  final _languageCtrl = TextEditingController();
  final _timezoneCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _languageCtrl.dispose();
    _timezoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);

    final profile = profileAsync.value;
    if (profile != null) {
      _usernameCtrl.text = profile.username ?? _usernameCtrl.text;
      _displayNameCtrl.text = profile.displayName ?? _displayNameCtrl.text;
      _bioCtrl.text = profile.bio ?? _bioCtrl.text;
      _languageCtrl.text = profile.language ?? _languageCtrl.text;
      _timezoneCtrl.text = profile.timezone ?? _timezoneCtrl.text;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF121516),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 58,
                    backgroundImage: profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
                        ? NetworkImage(profile.avatarUrl!)
                        : const AssetImage('assets/images/avatar.png') as ImageProvider,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        await controller.pickAndUploadAvatar(source: ImageSource.gallery);
                        if (mounted) showToast(context, 'Avatar updated', success: true);
                      },
                      icon: const Icon(Icons.camera_alt_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Username
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppInput(
                        controller: _usernameCtrl,
                        hint: 'Username',
                        icon: Icons.alternate_email,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Username is required' : null,
                        onChanged: (v) => controller.checkUsernameDebounced(v.trim()),
                      ),
                      if (_usernameHelper(ref) != null) ...[
                        const SizedBox(height: 6),
                        _usernameHelper(ref)!,
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Display name
                  AppInput(
                    controller: _displayNameCtrl,
                    hint: 'Display name',
                    icon: Icons.person_outline,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Display name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  // Bio (multiline)
                  AppInput(controller: _bioCtrl, hint: 'Bio', maxLines: 3),
                  const SizedBox(height: 16),
                  _DateField(
                    label: 'Date of birth',
                    initial: profile?.dateOfBirth,
                    onPicked: (d) => _dob = d,
                  ),
                  const SizedBox(height: 16),
                  AppInput(controller: _languageCtrl, hint: 'Language', icon: Icons.language),
                  const SizedBox(height: 16),
                  AppInput(controller: _timezoneCtrl, hint: 'Timezone', icon: Icons.public),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: profileAsync.isLoading
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              await controller.updateProfile(
                                username: _usernameCtrl.text.trim(),
                                displayName: _displayNameCtrl.text.trim(),
                                bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
                                dateOfBirth: _dob,
                                timezone: _timezoneCtrl.text.trim().isEmpty
                                    ? null
                                    : _timezoneCtrl.text.trim(),
                                language: _languageCtrl.text.trim().isEmpty
                                    ? null
                                    : _languageCtrl.text.trim(),
                              );
                              final err = ref.read(profileControllerProvider).error;
                              if (err == null && mounted) {
                                showToast(context, 'Profile updated', success: true);
                              } else if (mounted) {
                                showToast(context, err.toString());
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: profileAsync.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _usernameHelper(WidgetRef ref) {
    final a = ref.watch(profileControllerProvider.notifier).usernameAvailability;
    if (a == null) return null;
    final ok = a.available;
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.error_outline,
          size: 16,
          color: ok ? Colors.green : Colors.redAccent,
        ),
        const SizedBox(width: 6),
        Text(
          ok ? 'Username is available' : 'Username is taken',
          style: TextStyle(color: ok ? Colors.green : Colors.redAccent),
        ),
      ],
    );
  }
}

class _DateField extends StatefulWidget {
  const _DateField({required this.label, this.initial, required this.onPicked});
  final String label;
  final DateTime? initial;
  final ValueChanged<DateTime> onPicked;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final initial = _selected ?? DateTime(now.year - 18, now.month, now.day);
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(1900),
          lastDate: now,
          initialDate: initial,
          helpText: widget.label,
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Colors.white,
                onPrimary: Colors.black,
                surface: Color(0xFF222629),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          setState(() => _selected = picked);
          widget.onPicked(picked);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined, color: Colors.white70),
            const SizedBox(width: 12),
            Text(
              _selected != null
                  ? '${_selected!.year}-${_selected!.month.toString().padLeft(2, '0')}-${_selected!.day.toString().padLeft(2, '0')}'
                  : widget.label,
              style: TextStyle(color: _selected != null ? Colors.white : Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
