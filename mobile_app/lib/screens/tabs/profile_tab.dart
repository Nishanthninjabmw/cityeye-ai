import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/alert_service.dart';
import '../../theme/app_theme.dart';
import '../landing_screen.dart';

class ProfileTab extends StatefulWidget {
  final Function(int tabIndex) onTabSwitch;

  const ProfileTab({super.key, required this.onTabSwitch});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final ApiService _api = ApiService();
  final AlertService _alertService = AlertService();

  late TextEditingController _serverUrlController;
  bool _testingConnection = false;
  String? _connectionTestResult;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController(text: _api.baseUrl);
    _soundEnabled = _alertService.soundEnabled;
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _testAndSaveServer() async {
    setState(() {
      _testingConnection = true;
      _connectionTestResult = null;
    });

    await _api.setBaseUrl(_serverUrlController.text);
    final isHealthy = await _api.checkHealth();

    if (!mounted) return;
    setState(() {
      _testingConnection = false;
      _connectionTestResult = isHealthy
          ? '✓ Connected successfully to CityEye AI Backend!'
          : '✗ Server unreachable at this IP. Operating in Offline Demo mode.';
    });
  }

  Future<void> _handleLogout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final officer = _api.currentOfficer;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Officer Profile & System Config'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Officer Details Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.blueLight,
                          child: const Icon(
                            Icons.person,
                            size: 30,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                officer?.name ?? 'Inspector Sharma',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${officer?.officerId ?? "OFFICER-701"} • ${officer?.department ?? "Smoke Detection"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _handleLogout,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.errorRed,
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Logout', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.cardBorder),
                    const SizedBox(height: 12),
                    _buildProfileRow('Duty Phone:', officer?.phone ?? '+91 9876543210'),
                    const SizedBox(height: 6),
                    _buildProfileRow('Date of Birth:', '${officer?.dob ?? "1995-05-15"} (${officer?.age ?? 29} yrs)'),
                    const SizedBox(height: 6),
                    _buildProfileRow('Gov ID Verification:', 'Verified ✓ (${officer?.govIdProof ?? "Badge_Doc.pdf"})'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Server Connection Settings Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.dns_outlined, color: AppColors.primaryBlue, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Backend Server Connection',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _api.isOnline ? AppColors.successBg : AppColors.warningBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _api.isOnline ? 'ONLINE' : 'OFFLINE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _api.isOnline ? AppColors.successText : AppColors.warningText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Mac LAN IP & Port for REST API and MJPEG Webcam Stream:',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(
                        hintText: 'http://172.20.10.5:5000',
                        prefixIcon: Icon(Icons.link, size: 20),
                      ),
                    ),
                    if (_connectionTestResult != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _connectionTestResult!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _connectionTestResult!.contains('✓')
                              ? AppColors.successText
                              : AppColors.errorRed,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        onPressed: _testingConnection ? null : _testAndSaveServer,
                        child: _testingConnection
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save & Test Connection'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.cardBorder),
                    const SizedBox(height: 8),

                    // Sound Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Incident Alert Sound & Vibration',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Play system alert tone upon automated detection',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      value: _soundEnabled,
                      activeThumbColor: AppColors.primaryBlue,
                      onChanged: (val) {
                        setState(() => _soundEnabled = val);
                        _alertService.setSoundEnabled(val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Faculty Viva Demo Trigger Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.science_outlined, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Faculty Viva Demo Triggers',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Reliably demonstrate the real-time alert popup, sound chime, dashboard warning state, and incident log creation during viva testing.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 14),

                    // Demo Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await _api.triggerDemo('Smoke', 94.0);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('🔴 Smoke Alert triggered (94.0% AI confidence)!'),
                                  backgroundColor: AppColors.errorRed,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            child: const Text(
                              'Trigger Smoke Alert 🔴',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await _api.triggerDemo('Accident', 92.5);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('⚠️ Road Accident Alert triggered (92.5% AI confidence)!'),
                                  backgroundColor: Color(0xFFD97706),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            child: const Text(
                              'Trigger Accident Alert ⚠️',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          _alertService.clearHistory();
                          await _api.resetDemo();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('🔄 All alerts cleared. Both Smoke and Accident monitors returned to Normal.'),
                              backgroundColor: AppColors.successText,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        child: const Text(
                          'Clear / Reset All Alerts 🔄',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
}
