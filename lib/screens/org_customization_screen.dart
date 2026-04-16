import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/helper_functions/organization_context.dart';
import 'package:regie_data/screens/subscription_screen.dart';
import 'package:regie_data/services/subscription_service.dart';

const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);

// org customization
// business plan: accent color, logo Url, welcome msg, contact info
// stored in organization/{orgId}.branding

class OrgCustomizationScreen extends StatefulWidget {
  const OrgCustomizationScreen({super.key});

  @override
  State<OrgCustomizationScreen> createState() => _OrgCustomizationScreenState();
}

class _OrgCustomizationScreenState extends State<OrgCustomizationScreen> {
  final _db = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isSaving = false;
  String _userPlan = 'free';

  // Branding fields
  late TextEditingController _logoUrlCtrl;
  late TextEditingController _welcomeMsgCtrl;
  late TextEditingController _contactEmailCtrl;
  late TextEditingController _contactPhoneCtrl;
  late TextEditingController _websiteCtrl;
  Color _accentColor = const Color(0xFF22C55E);
  String _selectedColorHex = '#22C55E';

  // Preset accent colors to choose from
  static const _presetColors = [
    Color(0xFF22C55E), // Regie green
    Color(0xFF3B82F6), // Blue
    Color(0xFFA855F7), // Purple
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF2DD4BF), // Teal
    Color(0xFFEC4899), // Pink
    Color(0xFF6366F1), // Indigo
    Color(0xFFF97316), // Orange
  ];

  @override
  void initState() {
    super.initState();
    _logoUrlCtrl = TextEditingController();
    _welcomeMsgCtrl = TextEditingController();
    _contactEmailCtrl = TextEditingController();
    _contactPhoneCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _logoUrlCtrl.dispose();
    _welcomeMsgCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) _userPlan = await SubscriptionService.getUserPlan(uid);

    if (_userPlan == 'business') {
      final orgId = await OrganizationContext.getCurrentOrganizationId();
      if (orgId != null) {
        final doc = await _db.collection('organizations').doc(orgId).get();
        final data = doc.data() ?? {};
        final branding = data['branding'] as Map<String, dynamic>? ?? {};

        _logoUrlCtrl.text = branding['logoUrl'] ?? '';
        _welcomeMsgCtrl.text = branding['welcomMessage'] ?? '';
        _contactEmailCtrl.text = branding['contactEmail'] ?? '';
        _contactPhoneCtrl.text = branding['contactPhone'] ?? '';
        _websiteCtrl.text = branding['website'] ?? '';
        final hexStr = (branding['accentColor'] as String?) ?? '#22C55E';
        _selectedColorHex = hexStr;
        _accentColor = _hexToColor(hexStr);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final orgId = await OrganizationContext.getCurrentOrganizationId();
      if (orgId == null) throw 'No organization';

      await _db.collection('organizations').doc(orgId).update({
        'branding': {
          'logoUrl': _logoUrlCtrl.text.trim(),
          'welcomeMessage': _welcomeMsgCtrl.text.trim(),
          'contactEmail': _contactEmailCtrl.text.trim(),
          'contactPhone': _contactPhoneCtrl.text.trim(),
          'website': _websiteCtrl.text.trim(),
          'accentColor': _selectedColorHex,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      });

      if (mounted) {
        _snack('Customization saved!');
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (mounted) {
        _snack('Error: $e', error: true);
        setState(() => _isSaving = false);
      }
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade800 : _greenDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    if (h.length != 6) return _green;
    return Color(int.parse('FF$h', radix: 16));
  }

  String _colorToHex(Color color) =>
      '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white.withOpacity(0.7)),
        title: const Text('Organization Branding',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        actions: [
          if (_userPlan == 'business' && !_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: _isSaving ? null : _save,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [_green, _greenDark]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: Colors.white.withOpacity(0.06),
            )),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _green, strokeWidth: 2))
          : _userPlan != 'business'
              ? _upgradeWall()
              : _buildForm(),
    );
  }

  Widget _upgradeWall() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
                border: Border.all(color: _green.withOpacity(0.2)),
              ),
              child:
                  const Icon(Icons.palette_outlined, color: _green, size: 40),
            ),
            const SizedBox(height: 24),
            const Text('Business Plan Feature',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(
              'Custom branding is available on the Business plan. '
              'Set your organization\'s accent color, logo, and contact info.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 14,
                  height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen())),
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_green, _greenDark]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('Upgrade to Business',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // live preview banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accentColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accentColor.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: _logoUrlCtrl.text.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadiusGeometry.circular(8),
                            child: Image.network(
                              _logoUrlCtrl.text,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                  Icons.business_outlined,
                                  color: _accentColor,
                                  size: 22),
                            ),
                          )
                        : Icon(Icons.business_outlined,
                            color: _accentColor, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Live Preview',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      Text(
                          _welcomeMsgCtrl.text.isNotEmpty
                              ? _welcomeMsgCtrl.text
                              : 'Welcome to your organization!',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Accent color
          _sectionCard('Accent Color', Icons.palette_outlined, _accentColor,
              child: Column(
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _presetColors.map((color) {
                      final isSelected = _accentColor.value == color.value;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _accentColor = color;
                          _selectedColorHex = _colorToHex(color);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                        color: color.withOpacity(0.5),
                                        blurRadius: 10)
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Text('Hex: $_selectedColorHex',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.35), fontSize: 12)),
                ],
              )),
          const SizedBox(height: 16),

          // Logo
          _sectionCard('Log URL', Icons.image_outlined, const Color(0xFF3B82F6),
              child: _field(_logoUrlCtrl, 'https://example.com/logo.png',
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setState(() {}))),
          const SizedBox(height: 16),

          // Welcome message
          _sectionCard('Welcome Message', Icons.waving_hand_outlined,
              const Color(0xFFF59E0B),
              child: _field(_welcomeMsgCtrl, 'Welcome to our community!',
                  maxLines: 3, onChanged: (_) => setState(() {}))),
          const SizedBox(height: 16),

          // contact info
          _sectionCard('Contact Information', Icons.contact_mail_outlined,
              const Color(0xFFA855F7),
              child: Column(
                children: [
                  _field(_contactEmailCtrl, 'admin@myorg.com',
                      keyboardType: TextInputType.emailAddress,
                      label: 'Contact Email'),
                  const SizedBox(height: 10),
                  _field(_contactPhoneCtrl, '+233 XX XXX XXXX',
                      keyboardType: TextInputType.phone,
                      label: 'Contact Phone'),
                  const SizedBox(height: 10),
                  _field(_websiteCtrl, 'https://myorg.com',
                      keyboardType: TextInputType.url, label: 'Website'),
                ],
              )),

          const SizedBox(height: 28),

          GestureDetector(
            onTap: _isSaving ? null : _save,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: _isSaving
                    ? null
                    : const LinearGradient(colors: [_green, _greenDark]),
                color: _isSaving ? Colors.white.withOpacity(0.05) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _isSaving
                    ? const CircularProgressIndicator(
                        color: _green, strokeWidth: 2)
                    : const Text('Save Branding',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, IconData icon, Color color,
      {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? label,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
        ],
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: _green,
          onChanged: onChanged,
          decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _green))),
        )
      ],
    );
  }
}
