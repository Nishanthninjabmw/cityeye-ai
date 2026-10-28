import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/incident_model.dart';
import '../../theme/app_theme.dart';

class IncidentsTab extends StatefulWidget {
  const IncidentsTab({super.key});

  @override
  State<IncidentsTab> createState() => _IncidentsTabState();
}

class _IncidentsTabState extends State<IncidentsTab> {
  final ApiService _api = ApiService();
  String _selectedFilter = 'All';
  List<IncidentModel> _incidents = [];
  bool _isLoading = false;

  final List<String> _filters = [
    'All',
    'Smoke',
    'Fire',
    'Accident',
    'Open',
    'Investigating',
    'Resolved',
  ];

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    setState(() => _isLoading = true);
    final list = await _api.getIncidents(filter: _selectedFilter);
    if (mounted) {
      setState(() {
        _incidents = list;
        _isLoading = false;
      });
    }
  }

  void _showIncidentDetails(IncidentModel incident) {
    String currentStatus = incident.status;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.blueLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      incident.incidentId,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${incident.type} Detection Alert',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              // Details grid container
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Camera Node:', incident.cameraName),
                    const SizedBox(height: 8),
                    _buildModalRow('AI Confidence:', '${incident.confidence.toStringAsFixed(1)}%'),
                    const SizedBox(height: 8),
                    _buildModalRow('Severity Level:', incident.severity),
                    const SizedBox(height: 8),
                    _buildModalRow('Reported Time:', incident.timestamp),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Incident Description',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                incident.description,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.3),
              ),
              const SizedBox(height: 20),

              // Status update section
              const Text(
                'Update Resolution Status',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildStatusButton('Open', currentStatus, (val) {
                    setSheetState(() => currentStatus = val);
                  }),
                  const SizedBox(width: 8),
                  _buildStatusButton('Investigating', currentStatus, (val) {
                    setSheetState(() => currentStatus = val);
                  }),
                  const SizedBox(width: 8),
                  _buildStatusButton('Resolved', currentStatus, (val) {
                    setSheetState(() => currentStatus = val);
                  }),
                ],
              ),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    await _api.updateIncidentStatus(incident.id, currentStatus);
                    _loadIncidents();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Incident ${incident.incidentId} updated to "$currentStatus"'),
                        backgroundColor: AppColors.primaryDark,
                      ),
                    );
                  },
                  child: const Text('Save Status Update'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildStatusButton(String status, String current, Function(String) onSelect) {
    final isSelected = status.toLowerCase() == current.toLowerCase();
    Color activeColor;
    if (status == 'Open') {
      activeColor = AppColors.errorRed;
    } else if (status == 'Investigating') {
      activeColor = const Color(0xFFD97706);
    } else {
      activeColor = AppColors.successText;
    }

    return Expanded(
      child: InkWell(
        onTap: () => onSelect(status),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFCBD5E1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? activeColor : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Incident Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Incidents',
            onPressed: _loadIncidents,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            height: 48,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;

                return ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedFilter = filter);
                      _loadIncidents();
                    }
                  },
                  selectedColor: AppColors.primaryDark,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? AppColors.primaryDark : const Color(0xFFE2E8F0),
                    ),
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                );
              },
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.cardBorder),

          // Incident List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _incidents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 48, color: AppColors.successText),
                            const SizedBox(height: 12),
                            Text(
                              'No $_selectedFilter incidents found',
                              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadIncidents,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _incidents.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final inc = _incidents[index];
                            return _buildIncidentCard(inc);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(IncidentModel inc) {
    Color severityBg;
    Color severityText;
    if (inc.severity == 'Critical') {
      severityBg = const Color(0xFFFEF2F2);
      severityText = const Color(0xFFB91C1C);
    } else if (inc.severity == 'High') {
      severityBg = const Color(0xFFFFF7ED);
      severityText = const Color(0xFFC2410C);
    } else {
      severityBg = const Color(0xFFEFF6FF);
      severityText = AppColors.primaryBlue;
    }

    Color statusBg;
    Color statusText;
    if (inc.status == 'Open') {
      statusBg = const Color(0xFFFEF2F2);
      statusText = const Color(0xFFB91C1C);
    } else if (inc.status == 'Investigating') {
      statusBg = const Color(0xFFFFFBEB);
      statusText = const Color(0xFFB45309);
    } else {
      statusBg = const Color(0xFFECFDF5);
      statusText = const Color(0xFF047857);
    }

    return Card(
      child: InkWell(
        onTap: () => _showIncidentDetails(inc),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: ID + Status + Severity
              Row(
                children: [
                  Text(
                    inc.incidentId,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const Spacer(),
                  // Severity Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: severityBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      inc.severity.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: severityText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Status Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      inc.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                '${inc.type} Incident',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                inc.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),

              // Meta Row
              Row(
                children: [
                  const Icon(Icons.videocam_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    inc.cameraName,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Icons.bolt_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${inc.confidence.toStringAsFixed(1)}% AI Conf',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    inc.timestamp,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
