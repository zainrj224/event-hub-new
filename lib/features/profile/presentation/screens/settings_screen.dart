import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_notifier.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  bool _savingProfile = false;
  bool _notificationsEnabled = true;
  bool _publicProfile = true;

  String? _pickedPhotoDataUrl;
  String? _currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameCtrl.text = user?.displayName ?? '';
    _currentPhotoUrl = user?.photoURL;
    _loadBase64Photo();
  }

  Future<void> _loadBase64Photo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      final b64 = doc.data()?['photoBase64'] as String?;
      if (b64 != null && mounted) setState(() => _currentPhotoUrl = b64);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      final base64Str = base64Encode(file.bytes!);
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      setState(() => _pickedPhotoDataUrl = 'data:$mime;base64,$base64Str');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not pick image: $e'),
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_savingProfile) return;
    setState(() => _savingProfile = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      final name = _nameCtrl.text.trim();
      if (name.isNotEmpty) await user.updateDisplayName(name);

      String? finalPhotoUrl = _currentPhotoUrl;

      if (_pickedPhotoDataUrl != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'photoBase64': _pickedPhotoDataUrl}, SetOptions(merge: true));
        await user.updatePhotoURL('profile_photo_in_firestore');
        finalPhotoUrl = _pickedPhotoDataUrl;
      }

      await user.reload();

      setState(() {
        _currentPhotoUrl = finalPhotoUrl;
        _pickedPhotoDataUrl = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile updated!'),
            behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'This will permanently delete your account. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeNotifier.instance.isDark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? AppColors.darkText : AppColors.lightText;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final inputFill =
        isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);

    final displayName =
        FirebaseAuth.instance.currentUser?.displayName ?? '';
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final photoToShow = _pickedPhotoDataUrl ?? _currentPhotoUrl;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text('Settings',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 60),
        children: [

          // ── Edit Profile ─────────────────────────────────────────
          _label('EDIT PROFILE', textSecondary),
          const SizedBox(height: 12),
          _card(surface, border,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                // Avatar picker
                Center(
                  child: Stack(children: [
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.purple, width: 2.5),
                        ),
                        child: ClipOval(
                            child: _buildAvatar(photoToShow, initial)),
                      ),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Container(
                          width: 28, height: 28,
                          decoration: const BoxDecoration(
                              color: AppColors.purple,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _pickedPhotoDataUrl != null
                        ? 'Photo selected — tap Save to apply'
                        : 'Tap photo to change from gallery',
                    style:
                        TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ),
                const SizedBox(height: 16),

                _fieldLabel('Display Name', textSecondary),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  style: TextStyle(color: textPrimary),
                  decoration: _inputDeco(
                      'Your name', inputFill, border, textSecondary),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                    ),
                    onPressed:
                        _savingProfile ? null : _saveProfile,
                    child: _savingProfile
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Text('Save Profile',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                  ),
                ),
              ])),

          const SizedBox(height: 28),

          // ── Preferences ──────────────────────────────────────────
          _label('PREFERENCES', textSecondary),
          const SizedBox(height: 12),
          _card(surface, border,
              child: Column(children: [
                _toggle(
                  icon: Icons.dark_mode_rounded,
                  title: 'Dark Mode',
                  subtitle: 'Switch app theme',
                  value: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onChanged: (v) => ThemeNotifier.instance.setDark(v),
                ),
                Divider(
                    height: 1,
                    color: border,
                    indent: 16,
                    endIndent: 16),
                _toggle(
                  icon: Icons.notifications_rounded,
                  title: 'Push Notifications',
                  subtitle: 'Get notified about events',
                  value: _notificationsEnabled,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onChanged: (v) =>
                      setState(() => _notificationsEnabled = v),
                ),
              ])),

          const SizedBox(height: 28),

          // ── Privacy ──────────────────────────────────────────────
          _label('PRIVACY', textSecondary),
          const SizedBox(height: 12),
          _card(surface, border,
              child: _toggle(
                icon: Icons.public_rounded,
                title: 'Public Profile',
                subtitle: 'Let others discover your profile',
                value: _publicProfile,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onChanged: (v) => setState(() => _publicProfile = v),
              )),

          const SizedBox(height: 28),

          // ── Danger Zone ──────────────────────────────────────────
          _label('DANGER ZONE', const Color(0xFFEF4444)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA))),
            child: ListTile(
              leading: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person_remove_rounded,
                    color: Color(0xFFEF4444), size: 20),
              ),
              title: const Text('Delete Account',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB91C1C))),
              subtitle: const Text('Permanently remove your account',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFFEF4444))),
              onTap: _confirmDeleteAccount,
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar ────────────────────────────────────────────────────────────

  Widget _buildAvatar(String? photo, String initial) {
    if (photo != null && photo.startsWith('data:')) {
      try {
        final bytes = base64Decode(photo.split(',').last);
        return Image.memory(bytes,
            fit: BoxFit.cover, width: 90, height: 90);
      } catch (_) {}
    }
    if (photo != null &&
        photo.startsWith('http') &&
        photo != 'profile_photo_in_firestore') {
      return Image.network(photo,
          fit: BoxFit.cover, width: 90, height: 90,
          errorBuilder: (_, __, ___) => _initialsBox(initial));
    }
    return _initialsBox(initial);
  }

  Widget _initialsBox(String initial) => Container(
        color: AppColors.purpleLight,
        child: Center(
          child: Text(initial,
              style: const TextStyle(
                  color: AppColors.purple,
                  fontWeight: FontWeight.w700,
                  fontSize: 32)),
        ),
      );

  // ── Helpers ───────────────────────────────────────────────────────────

  Widget _label(String t, Color c) => Text(t,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: c));

  Widget _fieldLabel(String t, Color c) => Text(t,
      style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: c));

  Widget _card(Color surface, Color border, {required Widget child}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border)),
        child: child,
      );

  InputDecoration _inputDeco(
          String hint, Color fill, Color border, Color hintC) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintC),
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.purple, width: 2)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      );

  Widget _toggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color textPrimary,
    required Color textSecondary,
    required ValueChanged<bool> onChanged,
  }) =>
      ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: AppColors.purpleLight,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.purple, size: 20),
        ),
        title: Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textPrimary)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: textSecondary)),
        trailing: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.purple),
      );
}
