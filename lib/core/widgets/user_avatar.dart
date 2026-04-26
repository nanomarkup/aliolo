import 'package:flutter/material.dart';
import 'package:aliolo/data/models/user_model.dart';

class UserAvatar extends StatelessWidget {
  final UserModel user;
  final double radius;
  final Color? iconColor;

  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 20,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final avatarPath = user.avatarPath;
    final color = iconColor ?? Theme.of(context).primaryColor;

    if (avatarPath == null || avatarPath.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(Icons.person, size: radius, color: color),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.1),
      child: ClipOval(
        child: Image.network(
          avatarPath,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.person, size: radius, color: color);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: radius,
                height: radius,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
