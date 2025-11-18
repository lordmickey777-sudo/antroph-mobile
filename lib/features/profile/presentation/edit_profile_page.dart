import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/profile_controller.dart';
import '../../../widgets/toast.dart';
import 'package:antroph_mobile/widgets/app_input.dart';
import 'package:antroph_mobile/widgets/app_date_input.dart';

const Map<String, String> _languageOptions = {
  'en': 'English',
  'fr': 'French',
  'es': 'Spanish',
  'de': 'German',
  'it': 'Italian',
};

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
  String? _selectedLanguage;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
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
      if (_selectedLanguage == null && profile.language != null) {
        if (_languageOptions.containsKey(profile.language)) {
          _selectedLanguage = profile.language;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: const Color(0xFF121516),
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
                        onChanged: (v) => controller.checkUsernameImmediate(v.trim()),
                        trailing: _usernameStatusInline(ref),
                      ),
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
                  AppDateInput(
                    hint: 'Date of birth',
                    value: profile?.dateOfBirth ?? _dob,
                    onChanged: (d) => setState(() => _dob = d),
                  ),
                  const SizedBox(height: 16),
                  _LanguageDropdown(
                    value: _selectedLanguage,
                    onChanged: (value) => setState(() => _selectedLanguage = value),
                  ),
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
                                language: _selectedLanguage,
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
                        padding: const EdgeInsets.symmetric(vertical: 18),
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
    // Removed usage; keeping commented placeholder for potential future extended status text.
    return null; // TODO: Remove method entirely if not reinstated.
  }

  /// Inline compact status for username availability.
  Widget? _usernameStatusInline(WidgetRef ref) {
    final controller = ref.watch(profileControllerProvider.notifier);
    if (controller.isCheckingUsername) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(Colors.white70),
        ),
      );
    }
    final a = controller.usernameAvailability;
    if (a == null) return null;
    return Icon(
      a.available ? Icons.check_circle : Icons.error_outline,
      size: 20,
      color: a.available ? Colors.green : Colors.redAccent,
    );
  }
}

// Removed legacy _DateField in favor of reusable AppDateInput.

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2223),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        children: [
          const Icon(Icons.language, color: Colors.white70, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: value,
              dropdownColor: const Color(0xFF1F2223),
              borderRadius: BorderRadius.circular(12),
              iconEnabledColor: Colors.white70,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: 'Language',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                contentPadding: EdgeInsets.zero,
              ),
              items: [
                for (final entry in _languageOptions.entries)
                  DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
              ],
              onChanged: onChanged,
              validator: (value) => value == null || value.isEmpty ? 'Please select a language' : null,
            ),
          ),
        ],
      ),
    );
  }
}
