import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/officer_model.dart';
import '../models/camera_model.dart';
import '../models/incident_model.dart';
import '../models/detection_status_model.dart';

class ApiService extends ChangeNotifier {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Default LAN IP detected on Mac Wi-Fi
  static const String defaultServerUrl = 'http://172.20.10.5:5000';
  static const String accessGatePassword = '100City';

  String _baseUrl = defaultServerUrl;
  bool _isOnline = false;
  Officer? _currentOfficer;
  bool _isGateUnlocked = false;

  // Local in-memory state for offline resilience
  List<IncidentModel> _localIncidents = IncidentModel.defaultIncidents();
  List<CameraModel> _localCameras = CameraModel.defaultCameras();
  DetectionStatusModel _lastDetection = DetectionStatusModel.smokeNormal();
  DetectionStatusModel _lastSmokeDetection = DetectionStatusModel.smokeNormal();
  DetectionStatusModel _lastAccidentDetection = DetectionStatusModel.accidentNormal();

  String get baseUrl => _baseUrl;
  bool get isOnline => _isOnline;
  Officer? get currentOfficer => _currentOfficer;
  bool get isGateUnlocked => _isGateUnlocked;
  DetectionStatusModel get lastDetection => _lastDetection;
  DetectionStatusModel get lastSmokeDetection => _lastSmokeDetection;
  DetectionStatusModel get lastAccidentDetection => _lastAccidentDetection;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('backend_server_url') ?? defaultServerUrl;
    _isGateUnlocked = prefs.getBool('is_gate_unlocked') ?? false;
    
    final officerJson = prefs.getString('saved_officer');
    if (officerJson != null) {
      try {
        _currentOfficer = Officer.fromJson(jsonDecode(officerJson));
      } catch (_) {
        _currentOfficer = Officer.demoOfficer();
      }
    }
    
    // Test initial connection asynchronously
    checkHealth();
  }

  Future<void> setBaseUrl(String url) async {
    var cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'http://$cleanUrl';
    }
    _baseUrl = cleanUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_server_url', _baseUrl);
    await checkHealth();
    notifyListeners();
  }

  Future<bool> verifyAccessGate(String password) async {
    if (password.trim() == accessGatePassword) {
      _isGateUnlocked = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_gate_unlocked', true);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        _isOnline = true;
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Offline fallback
    }

    // Auto-try alternative port (5000 <-> 5001) for macOS AirPlay conflict resilience
    if (_baseUrl.contains(':5000')) {
      final altUrl = _baseUrl.replaceAll(':5000', ':5001');
      try {
        final res = await http.get(Uri.parse('$altUrl/health')).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          _baseUrl = altUrl;
          _isOnline = true;
          notifyListeners();
          return true;
        }
      } catch (_) {}
    } else if (_baseUrl.contains(':5001')) {
      final altUrl = _baseUrl.replaceAll(':5001', ':5000');
      try {
        final res = await http.get(Uri.parse('$altUrl/health')).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          _baseUrl = altUrl;
          _isOnline = true;
          notifyListeners();
          return true;
        }
      } catch (_) {}
    }

    _isOnline = false;
    notifyListeners();
    return false;
  }

  // --- AUTH ---
  Future<bool> login(String officerId, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'officer_id': officerId, 'password': password}),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentOfficer = Officer.fromJson(data['officer']);
        await _saveOfficerSession(_currentOfficer!);
        _isOnline = true;
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Backend offline fallback: allow demo login
    }

    // Offline demo fallback login
    if (officerId.isNotEmpty) {
      _currentOfficer = Officer(
        officerId: officerId,
        name: 'Inspector Sharma',
        department: 'Smoke Detection',
        dob: '1995-05-15',
        age: 29,
        phone: '+91 9876543210',
        token: 'offline_token',
      );
      await _saveOfficerSession(_currentOfficer!);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> quickDemoLogin() async {
    _currentOfficer = Officer.demoOfficer();
    await _saveOfficerSession(_currentOfficer!);
    notifyListeners();
    return true;
  }

  Future<bool> register({
    required String name,
    required String department,
    required String dob,
    required int age,
    required String officerId,
    required String phone,
    required String password,
    String? govIdProof,
  }) async {
    final officer = Officer(
      officerId: officerId,
      name: name,
      department: department,
      dob: dob,
      age: age,
      phone: phone,
      govIdProof: govIdProof ?? 'Gov_ID_Verified.pdf',
    );

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'officer_id': officerId,
              'name': name,
              'department': department,
              'dob': dob,
              'age': age,
              'phone': phone,
              'password': password,
              'gov_id_proof': govIdProof ?? 'Gov_ID_Verified.pdf',
            }),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _currentOfficer = data['officer'] != null 
            ? Officer.fromJson(data['officer']) 
            : officer;
        await _saveOfficerSession(_currentOfficer!);
        _isOnline = true;
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Offline fallback
    }

    _currentOfficer = officer;
    await _saveOfficerSession(_currentOfficer!);
    notifyListeners();
    return true;
  }

  Future<void> _saveOfficerSession(Officer officer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_officer', jsonEncode(officer.toJson()));
  }

  Future<void> logout() async {
    _currentOfficer = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_officer');
    notifyListeners();
  }

  // --- DASHBOARD STATS ---
  Future<Map<String, int>> getDashboardStats() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/dashboard'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _isOnline = true;
        return {
          'totalCameras': data['totalCameras'] ?? 2,
          'onlineCameras': data['onlineCameras'] ?? 1,
          'totalIncidents': data['totalIncidents'] ?? _localIncidents.length,
          'activeIncidents': data['activeIncidents'] ?? _localIncidents.where((i) => i.status != 'Resolved').length,
        };
      }
    } catch (_) {
      _isOnline = false;
    }

    // Offline fallback calculations
    return {
      'totalCameras': _localCameras.length,
      'onlineCameras': _localCameras.where((c) => c.isOnline).length,
      'totalIncidents': _localIncidents.length,
      'activeIncidents': _localIncidents.where((i) => i.status != 'Resolved').length,
    };
  }

  // --- CAMERAS ---
  Future<List<CameraModel>> getCameras() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/cameras'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _localCameras = data.map((item) => CameraModel.fromJson(item)).toList();
        _isOnline = true;
        notifyListeners();
        return _localCameras;
      }
    } catch (_) {
      _isOnline = false;
    }
    return _localCameras;
  }

  // --- INCIDENTS ---
  Future<List<IncidentModel>> getIncidents({String? filter}) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/incidents'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _localIncidents = data.map((item) => IncidentModel.fromJson(item)).toList();
        _isOnline = true;
      }
    } catch (_) {
      _isOnline = false;
    }

    if (filter == null || filter == 'All') {
      return _localIncidents;
    }
    return _localIncidents.where((item) {
      if (filter == 'Smoke' || filter == 'Fire' || filter == 'Accident') {
        return item.type.toLowerCase() == filter.toLowerCase();
      }
      return item.status.toLowerCase() == filter.toLowerCase();
    }).toList();
  }

  Future<bool> updateIncidentStatus(int id, String newStatus) async {
    // Update local immediately for responsiveness
    final index = _localIncidents.indexWhere((i) => i.id == id);
    if (index != -1) {
      _localIncidents[index].status = newStatus;
      notifyListeners();
    }

    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/api/incidents/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': newStatus}),
          )
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        _isOnline = true;
        return true;
      }
    } catch (_) {
      _isOnline = false;
    }
    return true; // Still true because local state was updated
  }

  // --- DETECTION STATUS ---
  Future<DetectionStatusModel> getDetectionStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/detection/status'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _lastDetection = DetectionStatusModel.fromJson(data);
        if (data['smoke'] != null) {
          _lastSmokeDetection = DetectionStatusModel.fromJson(data['smoke'], defaultType: 'Smoke');
        } else if (_lastDetection.detectionType.toLowerCase() == 'smoke') {
          _lastSmokeDetection = _lastDetection;
        }
        if (data['accident'] != null) {
          _lastAccidentDetection = DetectionStatusModel.fromJson(data['accident'], defaultType: 'Accident');
        } else if (_lastDetection.detectionType.toLowerCase() == 'accident') {
          _lastAccidentDetection = _lastDetection;
        }
        _isOnline = true;
        notifyListeners();
        return _lastDetection;
      }
    } catch (_) {
      _isOnline = false;
    }
    return _lastDetection;
  }

  // --- DEMO TRIGGERS (VIVA DEMONSTRATION) ---
  Future<void> triggerDemo(String type, double confidence) async {
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/api/detection/trigger_demo'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'type': type, 'confidence': confidence}),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Offline fallback: simulate local alert
    }

    final now = DateTime.now();
    final timeStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    final isAccident = type.toLowerCase() == 'accident';
    final alertMessage = isAccident
        ? 'Visual AI Alert: Vehicle collision and road hazard verified on Sector 4 roadway with ${confidence.toStringAsFixed(1)}% confidence.'
        : 'Visual AI Alert: $type plume verified in quadrant B with ${confidence.toStringAsFixed(1)}% confidence.';

    final alertModel = DetectionStatusModel(
      status: 'ALERT',
      detectionType: type,
      confidence: confidence,
      message: alertMessage,
      timestamp: timeStr,
      cameraId: 'CAM-01',
      incidentId: DateTime.now().millisecondsSinceEpoch % 10000,
    );

    _lastDetection = alertModel;
    if (isAccident) {
      _lastAccidentDetection = alertModel;
    } else {
      _lastSmokeDetection = alertModel;
    }

    // Also add to local incidents list
    _localIncidents.insert(
      0,
      IncidentModel(
        id: DateTime.now().millisecondsSinceEpoch,
        incidentId: 'INC-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 900) + 100}',
        type: type,
        severity: 'Critical',
        status: 'Open',
        cameraId: 'CAM-01',
        cameraName: 'Laptop Webcam',
        confidence: confidence,
        description: alertMessage,
        timestamp: 'Just now ($timeStr)',
      ),
    );

    notifyListeners();
  }

  Future<void> resetDemo() async {
    try {
      await http
          .post(Uri.parse('$_baseUrl/api/detection/reset'))
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Offline fallback
    }
    _lastSmokeDetection = DetectionStatusModel.smokeNormal();
    _lastAccidentDetection = DetectionStatusModel.accidentNormal();
    _lastDetection = DetectionStatusModel.smokeNormal();
    notifyListeners();
  }

  String get liveStreamUrl => '$_baseUrl/video_feed';
}
