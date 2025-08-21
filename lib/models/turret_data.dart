import 'package:flutter/foundation.dart';

@immutable
class TurretData {
  const TurretData({
    this.targetEnemyId,
    this.fireCooldown = 0,
  });

  final int? targetEnemyId;
  final int fireCooldown;

  TurretData copyWith({
    int? targetEnemyId,
    bool clearTarget = false,
    int? fireCooldown,
  }) {
    return TurretData(
      targetEnemyId: clearTarget ? null : targetEnemyId ?? this.targetEnemyId,
      fireCooldown: fireCooldown ?? this.fireCooldown,
    );
  }
}