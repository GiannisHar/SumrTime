import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/bar_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'package:image_picker/image_picker.dart';

// NOTE: Bar zone geofence radius and umbrella radius management remain
// platform-admin-only (X-Admin-Pin auth) — see the admin app / routes/admin.py.
// The "Use My Current Location" button below ONLY updates the bar owner's
// lat/lng via PUT /api/bars/me/location. It cannot touch radius_m — the
// server silently ignores that field on this endpoint by design.

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BarProvider>(
      builder: (context, prov, _) {
        final bar = prov.bar!;
        return Column(
          children: [
            const OceanHeader(title: 'Settings'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  // ── Bar info ─────────────────────────────────────────────
                  const SectionHeader(title: 'BAR INFO'),
                  _SettingsCard(children: [
                    _InfoRow(label: 'Name', value: bar.name),
                    _Divider(),
                    _InfoRow(label: 'Email', value: bar.ownerEmail),
                    _Divider(),
                    _InfoRow(
                      label: 'Location',
                      value: bar.location != null
                          ? '${bar.location!.lat.toStringAsFixed(4)}, '
                              '${bar.location!.lng.toStringAsFixed(4)}'
                          : 'Not set',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _useCurrentLocation(context),
                        icon: const Icon(Icons.my_location_rounded),
                        label: const Text('Use My Current Location'),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 4),

                  // ── Staff join code ───────────────────────────────────────
                  const SectionHeader(title: 'STAFF ACCESS'),
                  _SettingsCard(children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Staff Join Code',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bar.joinCode ?? '------',
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.ocean,
                                  letterSpacing: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              color: AppTheme.ocean),
                          tooltip: 'Copy code',
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: bar.joinCode ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Join code copied!',
                                    style: TextStyle(
                                        fontFamily: 'Nunito',
                                        fontWeight: FontWeight.w600)),
                                backgroundColor: AppTheme.seafoam,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Share this code with your staff. They use it together with their name and PIN to log in.',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),

                  // ── Logo ─────────────────────────────────────────────────
                  const SectionHeader(title: 'LOGO'),
                  const LogoUploadSection(),
                  const SizedBox(height: 4),

                  // ── Payments ─────────────────────────────────────────────
                  const SectionHeader(title: 'PAYMENTS'),
                  const _PaymentsSection(),
                  const SizedBox(height: 4),

                  // ── Menu theme ───────────────────────────────────────────
                  const SectionHeader(title: 'MENU THEME'),
                  _SettingsCard(children: [
                    _ColorRow(
                      label: 'Primary Color',
                      hexColor: bar.theme.primaryColor,
                      onChanged: (hex) =>
                          prov.updateTheme({'primary_color': hex}),
                    ),
                    _Divider(),
                    _ColorRow(
                      label: 'Secondary Color',
                      hexColor: bar.theme.secondaryColor,
                      onChanged: (hex) =>
                          prov.updateTheme({'secondary_color': hex}),
                    ),
                    _Divider(),
                    _ColorRow(
                      label: 'Background',
                      hexColor: bar.theme.backgroundColor,
                      onChanged: (hex) =>
                          prov.updateTheme({'background_color': hex}),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // ── Sign out ─────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context, prov),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        backgroundColor: AppTheme.danger.withOpacity(.05),
                        side: BorderSide(
                            color: AppTheme.danger.withOpacity(.4), width: 1.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign Out',
                          style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _useCurrentLocation(BuildContext context) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are off')),
        );
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Location permission permanently denied — enable it in Settings')),
        );
      }
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!context.mounted) return;
      await context.read<BarProvider>().updateLocation(pos.latitude, pos.longitude);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location updated',
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600)),
            backgroundColor: AppTheme.seafoam,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e',
                style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _confirmLogout(BuildContext context, BarProvider prov) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out',
            style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              prov.logout();
            },
            child: const Text('Sign Out',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Payments section
// ═══════════════════════════════════════════════════════════════════════════

class _PaymentsSection extends StatefulWidget {
  const _PaymentsSection();

  @override
  State<_PaymentsSection> createState() => _PaymentsSectionState();
}

class _PaymentsSectionState extends State<_PaymentsSection> {
  bool _loading    = true;
  bool _connecting = false;
  bool _isConnected      = false;
  bool _payoutsEnabled   = false;
  bool _chargesEnabled   = false;
  String? _stripeEmail;
  String? _stripeDashboardUrl;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getStripeStatus();
      if (!mounted) return;
      setState(() {
        _isConnected    = data['connected']        as bool? ?? false;
        _payoutsEnabled = data['payouts_enabled']  as bool? ?? false;
        _chargesEnabled = data['charges_enabled']  as bool? ?? false;
        _stripeEmail        = data['email']         as String?;
        _stripeDashboardUrl = data['dashboard_url'] as String?;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startConnect() async {
    setState(() => _connecting = true);
    try {
      final data = await ApiService.createStripeConnectLink();
      final url  = data['url'] as String?;
      if (url == null) throw Exception('No onboarding URL returned');
      final uri  = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not open browser');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e',
              style: const TextStyle(
                  fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _openDashboard() async {
    if (_stripeDashboardUrl == null) return;
    final uri = Uri.parse(_stripeDashboardUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _SettingsCard(children: [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: AppTheme.seafoam),
          ),
        ),
      ]);
    }

    if (_isConnected) {
      return _SettingsCard(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (_payoutsEnabled && _chargesEnabled)
                ? AppTheme.seafoam.withOpacity(0.1)
                : AppTheme.sunYellow.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (_payoutsEnabled && _chargesEnabled)
                  ? AppTheme.seafoam.withOpacity(0.3)
                  : AppTheme.sunYellow.withOpacity(0.3),
              width: 1.2,
            ),
          ),
          child: Row(children: [
            Icon(
              (_payoutsEnabled && _chargesEnabled)
                  ? Icons.check_circle_rounded
                  : Icons.hourglass_top_rounded,
              color: (_payoutsEnabled && _chargesEnabled)
                  ? AppTheme.seafoam
                  : AppTheme.sunYellow,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (_payoutsEnabled && _chargesEnabled)
                        ? 'Payments Active'
                        : 'Setup In Progress',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: (_payoutsEnabled && _chargesEnabled)
                          ? AppTheme.seafoam
                          : AppTheme.sunYellow,
                    ),
                  ),
                  if (_stripeEmail != null)
                    Text(_stripeEmail!,
                        style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ]),
        ),
        if (_payoutsEnabled && _chargesEnabled) ...[
          const SizedBox(height: 12),
          _StatusRow(icon: Icons.credit_card_rounded,      label: 'Card payments', ok: _chargesEnabled),
          const SizedBox(height: 6),
          _StatusRow(icon: Icons.account_balance_rounded,  label: 'Bank payouts',  ok: _payoutsEnabled),
          const SizedBox(height: 12),
          const Text(
            'Customer card payments go directly to your bank account. '
            'Only Stripe\'s standard processing fee applies (~1.5% + €0.25).',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppTheme.textSecondary),
          ),
        ] else ...[
          const SizedBox(height: 12),
          const Text(
            'Stripe is reviewing your details. Tap "Complete Setup" if you have remaining steps.',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Complete Setup',
            icon: Icons.open_in_new_rounded,
            onTap: _startConnect,
            loading: _connecting,
            color: AppTheme.sunYellow,
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openDashboard,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            side: const BorderSide(color: AppTheme.pebble, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('Open Stripe Dashboard',
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: _loadStatus,
            child: const Text('Refresh status',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ocean,
                    decoration: TextDecoration.underline)),
          ),
        ),
      ]);
    }

    return _SettingsCard(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.sunYellow.withOpacity(.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.sunYellow.withOpacity(.3), width: 1.2),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.sunYellow, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Connect your bank account to receive card payments. Takes about 2 minutes.',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 12),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      _BulletPoint(text: 'Payments go 100% to your bank account'),
      const SizedBox(height: 6),
      _BulletPoint(text: 'Only Stripe\'s processing fee (~1.5% + €0.25)'),
      const SizedBox(height: 6),
      _BulletPoint(text: 'We never see your banking details'),
      const SizedBox(height: 6),
      _BulletPoint(text: 'You\'ll need your IBAN and an ID document'),
      const SizedBox(height: 16),
      PrimaryButton(
        label: 'Connect Payments',
        icon: Icons.account_balance_rounded,
        onTap: _startConnect,
        loading: _connecting,
        color: AppTheme.coral,
      ),
    ]);
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ok;
  const _StatusRow({required this.icon, required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 15, color: AppTheme.textSecondary),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontFamily: 'Nunito', fontSize: 12,
              fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
      const Spacer(),
      Icon(ok ? Icons.check_circle_rounded : Icons.pending_rounded,
          size: 16, color: ok ? AppTheme.seafoam : AppTheme.sunYellow),
    ]);
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_rounded, size: 14, color: AppTheme.seafoam),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontFamily: 'Nunito', fontSize: 12,
                  fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════════════

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.pebble, width: 1.2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 16, color: AppTheme.pebble);
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String label;
  final String hexColor;
  final void Function(String) onChanged;

  const _ColorRow({required this.label, required this.hexColor, required this.onChanged});

  Color _parseHex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const Spacer(),
        GestureDetector(
          onTap: () => _showColorPicker(context),
          child: Row(
            children: [
              Text(hexColor,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontFamily: 'monospace', color: AppTheme.textSecondary)),
              const SizedBox(width: 8),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _parseHex(hexColor),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.pebble, width: 1.2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showColorPicker(BuildContext context) {
    final controller = TextEditingController(text: hexColor);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(label,
            style: const TextStyle(
                fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(hintText: '#0097A7'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.startsWith('#') && val.length == 7) onChanged(val);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LOGO UPLOAD SECTION
// ═══════════════════════════════════════════════════════════════════════════
class LogoUploadSection extends StatefulWidget {
  const LogoUploadSection({super.key});

  @override
  State<LogoUploadSection> createState() => _LogoUploadSectionState();
}

class _LogoUploadSectionState extends State<LogoUploadSection> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,        // keep the upload well under the 5 MB server cap
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      await context.read<BarProvider>().uploadLogo(bytes, picked.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bar     = context.watch<BarProvider>().bar;
    final logoUrl = bar?.theme.logoUrl;

    return _SettingsCard(children: [
      const Text('Logo',
          style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary)),
      const SizedBox(height: 12),
      Row(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              image: (logoUrl != null && logoUrl.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(logoUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: (logoUrl == null || logoUrl.isEmpty)
                ? const Icon(Icons.image_outlined, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _uploading ? null : _pickAndUpload,
              icon: _uploading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload),
              label: Text(_uploading ? 'Uploading…' : 'Change logo'),
            ),
          ),
        ],
      ),
    ]);
  }
}