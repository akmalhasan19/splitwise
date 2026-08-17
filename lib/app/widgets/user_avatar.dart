/// Avatar lingkaran inisial dari [User] — `lib/app/widgets/` (Minggu 3).
///
/// Warna dari `User.avatarColor` (hex string). Inisial = huruf pertama nama
/// (uppercase). Default bila warna tidak ter-parse.
library;

import 'package:flutter/material.dart';

import 'package:debt_splitter/core/models/user.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({required this.user, this.radius = 18, super.key});

  final User user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color =
        _parseColor(user.avatarColor) ?? Theme.of(context).colorScheme.primary;
    final initial = (user.name.isEmpty ? '?' : user.name[0]).toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  Color? _parseColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length == 6) {
      final value = int.tryParse('FF$clean', radix: 16);
      if (value != null) return Color(value);
    }
    return null;
  }
}
