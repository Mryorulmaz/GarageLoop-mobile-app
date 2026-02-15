import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/services/notification_service.dart';
import '../core/theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import '../../lib_navigation.dart' as nav show AppNavigator;
import '../auth/data/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  String _appVersion = '1.0.0';
  String _buildNumber = '1';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load app version info
    final packageInfo = await PackageInfo.fromPlatform();
    
    setState(() {
      _notificationsEnabled = prefs.getBool('settings_notifications') ?? true;
      _locationEnabled = prefs.getBool('settings_location') ?? true;
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
    
    // Load settings from Firestore
    await _loadSettingsFromFirestore();
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_notifications', _notificationsEnabled);
    await prefs.setBool('settings_location', _locationEnabled);
    
    // Save to Firestore
    await _saveSettingsToFirestore();
  }
  
  Future<void> _loadSettingsFromFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _notificationsEnabled = data?['settings']?['notifications'] ?? _notificationsEnabled;
          _locationEnabled = data?['settings']?['location'] ?? _locationEnabled;
        });
      }
    } catch (e) {
      debugPrint('Failed to load settings from Firestore: $e');
    }
  }
  
  Future<void> _saveSettingsToFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'settings': {
          'notifications': _notificationsEnabled,
          'location': _locationEnabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      });
    } catch (e) {
      debugPrint('Failed to save settings to Firestore: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.openSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryNavy,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Preferences'),
            _buildPreferencesSection(),
            const SizedBox(height: 24),
            
            _buildSectionTitle('Privacy & Security'),
            _buildPrivacySecuritySection(),
            const SizedBox(height: 24),
            
            _buildSectionTitle('About'),
            _buildAboutSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.openSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            subtitle: 'Receive notifications about your listings',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) async {
                setState(() {
                  _notificationsEnabled = value;
                });
                _savePrefs();
                // Request/disable notifications via service
                final ns = context.read<NotificationService>();
                if (value) {
                  await ns.initialize();
                  final settings = await ns.getNotificationSettings();
                  final status = settings.authorizationStatus;
                  final token = ns.fcmToken;
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        status == AuthorizationStatus.authorized && token != null
                          ? 'Notifications enabled (token acquired)'
                          : 'Notifications permission status: $status',
                      ),
                    ),
                  );
                } else {
                  // iOS/Android'da izin geri alınamaz; yalnızca yerel tercihleri kapatıyoruz
                  ns.clearBadgeCount();
                }
              },
              activeColor: const Color(0xFF4285F4),
            ),
          ),
          _SettingsDivider(),
          _SettingsTile(
            icon: Icons.location_on_outlined,
            title: 'Location Services',
            subtitle: 'Allow access to your location',
            trailing: Switch(
              value: _locationEnabled,
              onChanged: (value) async {
                setState(() {
                  _locationEnabled = value;
                });
                _savePrefs();
                if (value) {
                  LocationPermission permission = await Geolocator.checkPermission();
                  if (permission == LocationPermission.denied) {
                    permission = await Geolocator.requestPermission();
                  }
                  final granted = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(granted
                        ? 'Location permission granted'
                        : 'Location permission not granted'),
                    ),
                  );
                } else {
                  // İzni kapatmak için sistem ayarlarına yönlendirme önerisi
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('To disable completely, change from iOS Settings > Privacy > Location Services'),
                    ),
                  );
                }
              },
              activeColor: const Color(0xFF4285F4),
            ),
          ),
          // Removed Dark Mode toggle
          _SettingsDivider(),
          // Removed Currency tile
        ],
      ),
    );
  }

  Widget _buildPrivacySecuritySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
          _SettingsDivider(),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'The rules for using GarageLoop',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
            ),
          ),
          _SettingsDivider(),
          _SettingsTile(
            icon: Icons.cancel_outlined,
            title: 'Withdraw Consent',
            subtitle: 'Revoke Terms and Privacy Policy consent (GDPR)',
            onTap: _confirmAndWithdrawConsent,
          ),
          _SettingsDivider(),
          _SettingsTile(
            icon: Icons.delete_outline,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account',
            onTap: _confirmAndDeleteAccount,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndWithdrawConsent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Consent'),
        content: const Text(
          'This will revoke your consent to Terms of Service and Privacy Policy. You may need to accept them again to continue using certain features. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Withdrawing consent…')),
    );

    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not signed in')),
        );
        return;
      }

      await _authService.withdrawConsent(userId: user.uid);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consent withdrawn successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to withdraw consent: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmAndDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action is permanent. Your profile, listings, chats and tokens will be deleted. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleting account…')));

    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not signed in')));
        return;
      }

      // Attempt to delete auth user first (avoid wiping data if deletion fails)
      await user.delete();

      // Delete user-related data after auth delete succeeds
      await _firestore.collection('users').doc(user.uid).delete().catchError((_) {});
      await _firestore.collection('users').doc(user.uid).collection('tokens').doc('fcm').delete().catchError((_) {});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deleted')));
      // Giriş ekranına döndür (tüm stack'i temizle)
      nav.AppNavigator.toAuth(context);
    } on FirebaseAuthException catch (e) {
      // Requires recent login case
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'requires-recent-login'
                ? 'For security, please sign in again and retry account deletion.'
                : 'Failed to delete account: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete account: $e')));
    }
  }

  Widget _buildAboutSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'App Version',
            subtitle: '$_appVersion (Build $_buildNumber)',
            onTap: null,
          ),
        ],
      ),
    );
  }

  // Removed currency dialog

  // Removed currency selection handler

  // Removed delete account dialog
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Colors.blue.shade600,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.openSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.openSans(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey) : null),
      onTap: onTap,
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Colors.grey.shade200,
      indent: 72,
    );
  }
}

class CurrencyOption extends StatelessWidget {
  const CurrencyOption({
    super.key,
    required this.value,
    required this.label,
    required this.onSelected,
  });

  final String value;
  final String label;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        style: GoogleFonts.openSans(fontSize: 16),
      ),
      onTap: () => onSelected(value),
    );
  }
}