import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'registration_screen.dart';

class DepartmentItem {
  final String title;
  final String tag;
  final String description;
  final IconData icon;

  const DepartmentItem({
    required this.title,
    required this.tag,
    required this.description,
    required this.icon,
  });
}

class DepartmentScreen extends StatefulWidget {
  const DepartmentScreen({super.key});

  @override
  State<DepartmentScreen> createState() => _DepartmentScreenState();
}

class _DepartmentScreenState extends State<DepartmentScreen> {
  int _selectedIndex = 3; // Default to 'Smoke Detection' for the project viva

  final List<DepartmentItem> _departments = const [
    DepartmentItem(
      title: 'Police Department',
      tag: 'Law Enforcement',
      description: 'Emergency response, public safety, surveillance and crime prevention.',
      icon: Icons.local_police_outlined,
    ),
    DepartmentItem(
      title: 'Ambulance & EMS',
      tag: 'Emergency Medical',
      description: 'Paramedic dispatch, medical emergency coordination, hospital routing.',
      icon: Icons.medical_services_outlined,
    ),
    DepartmentItem(
      title: 'Traffic Police',
      tag: 'Transit & Highways',
      description: 'Road incident handling, congestion monitoring, highway patrol assistance.',
      icon: Icons.traffic_outlined,
    ),
    DepartmentItem(
      title: 'Smoke Detection',
      tag: 'AI Fire & Smoke Monitoring',
      description: 'Monitor the camera feed and view AI-detected fire and smoke alerts.',
      icon: Icons.local_fire_department_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Department Selection'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose the emergency branch you are authorized to operate under. Your access sector and incident dispatch routing will adapt accordingly.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Department Cards
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _departments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final dept = _departments[index];
                        final isSelected = _selectedIndex == index;

                        return InkWell(
                          onTap: () {
                            setState(() => _selectedIndex = index);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryBlue : AppColors.cardBorder,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon Box
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.blueLight : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    dept.icon,
                                    color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            dept.title,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (isSelected)
                                            const Icon(
                                              Icons.check_circle,
                                              color: AppColors.primaryBlue,
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.blueLight,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          dept.tag,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        dept.description,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        'Please select a department above to continue.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final selectedDept = _departments[_selectedIndex].title;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RegistrationScreen(selectedDepartment: selectedDept),
                      ),
                    );
                  },
                  child: const Text('Continue to Registration'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
