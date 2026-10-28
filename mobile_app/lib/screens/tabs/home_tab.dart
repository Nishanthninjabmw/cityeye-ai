import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/detection_status_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/mjpeg_stream_widget.dart';

class HomeTab extends StatefulWidget {
  final Function(int tabIndex) onTabSwitch;

  const HomeTab({super.key, required this.onTabSwitch});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ApiService _api = ApiService();
  Timer? _refreshTimer;
  Map<String, int> _stats = {
    'totalCameras': 2,
    'onlineCameras': 1,
    'totalIncidents': 3,
    'activeIncidents': 2,
  };
  DetectionStatusModel _smokeDetection = DetectionStatusModel.smokeNormal();
  DetectionStatusModel _accidentDetection = DetectionStatusModel.accidentNormal();

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollDetection();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final stats = await _api.getDashboardStats();
    await _api.getDetectionStatus();
    if (mounted) {
      setState(() {
        _stats = stats;
        _smokeDetection = _api.lastSmokeDetection;
        _accidentDetection = _api.lastAccidentDetection;
      });
    }
  }

  Future<void> _pollDetection() async {
    await _api.getDetectionStatus();
    final stats = await _api.getDashboardStats();
    if (mounted) {
      setState(() {
        _smokeDetection = _api.lastSmokeDetection;
        _accidentDetection = _api.lastAccidentDetection;
        _stats = stats;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final officer = _api.currentOfficer;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CityEye AI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Smart City Monitoring • ${officer?.department ?? "Smoke Detection"}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All emergency notifications are active and synchronized.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card 1 — Officer Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.blueLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppColors.primaryBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Officer Dashboard',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ready (${officer?.name ?? "Inspector Sharma"})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _api.isOnline
                          ? StatusBadge.online()
                          : StatusBadge.offline(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Card 2 — AI Fire & Smoke Monitor Status Card
              _buildSmokeDetectionCard(),
              const SizedBox(height: 12),

              // Card 2B — AI Accident Detection Monitor Status Card
              _buildAccidentDetectionCard(),
              const SizedBox(height: 20),

              // Section — Live Camera Monitoring
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Live Camera Monitoring',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onTabSwitch(1), // Switch to Cameras tab
                    child: const Text(
                      'View Cameras',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Camera Preview Box
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MjpegStreamWidget(
                  streamUrl: _api.liveStreamUrl,
                  height: 190,
                  fallbackSubtitle: 'Detection status is shown above',
                ),
              ),
              const SizedBox(height: 24),

              // Section — Today's Overview
              const Text(
                "Today's Overview",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // 2x2 Grid of Stat Cards
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _buildStatCard(
                    title: 'Total Cameras',
                    value: '${_stats['totalCameras'] ?? 2}',
                    icon: Icons.videocam_outlined,
                    iconColor: AppColors.primaryBlue,
                    bgColor: AppColors.blueLight,
                  ),
                  _buildStatCard(
                    title: 'Online Cameras',
                    value: '${_stats['onlineCameras'] ?? 1}',
                    icon: Icons.check_circle_outline,
                    iconColor: AppColors.successText,
                    bgColor: AppColors.successBg,
                  ),
                  _buildStatCard(
                    title: 'Total Incidents',
                    value: '${_stats['totalIncidents'] ?? 3}',
                    icon: Icons.warning_amber_rounded,
                    iconColor: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                  ),
                  _buildStatCard(
                    title: 'Active Incidents',
                    value: '${_stats['activeIncidents'] ?? 2}',
                    icon: Icons.error_outline,
                    iconColor: AppColors.errorRed,
                    bgColor: AppColors.alertBg,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmokeDetectionCard() {
    final isAlert = _smokeDetection.isAlert;

    if (!isAlert) {
      // Normal state (Green)
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'AI FIRE & SMOKE MONITOR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF15803D)),
                  onPressed: _pollDetection,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'NO FIRE OR SMOKE DETECTED',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF166534),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _smokeDetection.message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF15803D)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Last checked: ${_smokeDetection.timestamp}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A)),
                ),
                const Spacer(),
                const Text(
                  '● Refreshes every 2s',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Alert state (Red)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.alertBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.alertBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.errorRed,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'AI ${_smokeDetection.detectionType.toUpperCase()} ALERT ACTIVE',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.alertText,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.errorRed,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_smokeDetection.confidence.toStringAsFixed(1)}% CONFIDENCE',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_smokeDetection.detectionType.toUpperCase()} DETECTED ON LIVE FEED',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.alertText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _smokeDetection.message,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Detected: ${_smokeDetection.timestamp}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => widget.onTabSwitch(2), // Switch to Incidents tab
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View Incident', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccidentDetectionCard() {
    final isAlert = _accidentDetection.isAlert;

    if (!isAlert) {
      // Normal state (Green)
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.car_crash_outlined,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'AI ACCIDENT MONITOR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF15803D)),
                  onPressed: _pollDetection,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'NO ACCIDENT DETECTED',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF166534),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _accidentDetection.message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF15803D)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Last checked: ${_accidentDetection.timestamp}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A)),
                ),
                const Spacer(),
                const Text(
                  '● Refreshes every 2s',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Alert state (Red)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.alertBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.alertBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.car_crash_rounded,
                color: AppColors.errorRed,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI ACCIDENT ALERT ACTIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.alertText,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.errorRed,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_accidentDetection.confidence.toStringAsFixed(1)}% CONFIDENCE',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'ROAD ACCIDENT DETECTED ON LIVE FEED',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.alertText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _accidentDetection.message,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Detected: ${_accidentDetection.timestamp}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => widget.onTabSwitch(2), // Switch to Incidents tab
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View Incident', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
              ],
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
