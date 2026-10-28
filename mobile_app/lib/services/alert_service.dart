import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/detection_status_model.dart';
import '../models/incident_model.dart';
import 'api_service.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  Timer? _pollTimer;
  final Set<String> _notifiedIncidentIds = {};
  bool _soundEnabled = true;
  bool _isShowingDialog = false;

  bool get soundEnabled => _soundEnabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('alert_sound_enabled') ?? true;
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alert_sound_enabled', value);
  }

  void startPolling(
    BuildContext context, {
    required Function(int tabIndex, IncidentModel? incident) onNavigate,
  }) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final api = ApiService();
      try {
        final detection = await api.getDetectionStatus();
        if (detection.isAlert && context.mounted) {
          final alertKey = '${detection.detectionType}_${detection.incidentId ?? detection.timestamp}';
          if (!_notifiedIncidentIds.contains(alertKey) && !_isShowingDialog) {
            _notifiedIncidentIds.add(alertKey);
            _triggerAlert(context, detection, onNavigate);
          }
        }
      } catch (_) {
        // Suppress polling error in background
      }
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void clearHistory() {
    _notifiedIncidentIds.clear();
  }

  void _triggerAlert(
    BuildContext context,
    DetectionStatusModel detection,
    Function(int tabIndex, IncidentModel? incident) onNavigate,
  ) {
    if (_soundEnabled) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.vibrate();
    }

    _isShowingDialog = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '⚠️ ${detection.detectionType.toUpperCase()} DETECTED',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildRow('Camera Source:', 'Laptop Webcam (CAM-01)'),
                    const SizedBox(height: 6),
                    _buildRow('Timestamp:', detection.timestamp),
                    const SizedBox(height: 6),
                    _buildRow(
                      'AI Confidence:',
                      '${detection.confidence.toStringAsFixed(1)}%',
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                detection.message,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                _isShowingDialog = false;
                Navigator.pop(dialogCtx);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                _isShowingDialog = false;
                Navigator.pop(dialogCtx);
                // Switch to Incidents tab
                onNavigate(2, null);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('View Incident'),
            ),
          ],
        );
      },
    ).then((_) {
      _isShowingDialog = false;
    });
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
