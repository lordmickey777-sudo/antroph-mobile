class AuthValidators {
  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Email is required';
    // Basic email regex; backend will enforce stricter rules.
    final ok = RegExp(r'^\S+@\S+\.[\w-]+$').hasMatch(v);
    if (!ok) return 'Enter a valid email address';
    return null;
  }

  static String? resetToken(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Code is required';
    if (!RegExp(r'^\d{6}$').hasMatch(v)) return 'Code must be exactly 6 digits';
    return null;
  }

  static String? newPassword(String? value) {
    final v = (value ?? '');
    if (v.isEmpty) return 'New password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(v);
    final hasNumber = RegExp(r'\d').hasMatch(v);
    if (!(hasLetter && hasNumber)) return 'Use letters and numbers for a stronger password';
    return null;
  }
}
