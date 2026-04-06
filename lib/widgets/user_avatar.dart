import 'package:flutter/material.dart';

/// Returns a deterministic color for the given userId.
Color avatarColorForId(String userId) {
  const colors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF0EA5E9), // Sky Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF64748B), // Slate
  ];
  if (userId.isEmpty) return colors[0];
  int hash = 0;
  for (final c in userId.codeUnits) {
    hash = (hash * 31 + c) & 0xFFFFFFFF;
  }
  return colors[hash.abs() % colors.length];
}

/// Returns up to 2 initials for a display name.
String initialsFor(String displayName) {
  final parts = displayName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts[0].isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// A colored circle avatar with the user's initials — no network images.
class UserAvatar extends StatelessWidget {
  final String userId;
  final String displayName;
  final double radius;

  const UserAvatar({
    super.key,
    required this.userId,
    required this.displayName,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final color = avatarColorForId(userId);
    final initials = initialsFor(displayName.isNotEmpty ? displayName : '?');

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: radius * 0.75,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
