import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final bool isOnline;
  final bool isDisconnected;
  final bool isLive;

  const StatusBadge({
    super.key,
    required this.label,
    this.isOnline = true,
    this.isDisconnected = false,
    this.isLive = false,
  });

  factory StatusBadge.online() {
    return const StatusBadge(label: 'ONLINE', isOnline: true);
  }

  factory StatusBadge.offline() {
    return const StatusBadge(label: 'OFFLINE', isOnline: false);
  }

  factory StatusBadge.disconnected() {
    return const StatusBadge(label: 'DISCONNECTED', isDisconnected: true);
  }

  factory StatusBadge.live() {
    return const StatusBadge(label: 'LIVE FEED', isLive: true);
  }

  @override
  Widget build(BuildContext context) {
    if (isDisconnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.errorRed,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '● ',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }

    if (isLive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '● ',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }

    final bgColor = isOnline ? AppColors.successBg : AppColors.warningBg;
    final borderColor = isOnline ? AppColors.successBorder : AppColors.warningDot;
    final textColor = isOnline ? AppColors.successText : AppColors.warningText;
    final dotColor = isOnline ? AppColors.successDot : AppColors.warningDot;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
