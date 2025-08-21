import 'package:flutter/foundation.dart';

const int nestMaxHealth = 200;
const int enemyMaxHealth = 20;

@immutable
class EnemyNest {
  const EnemyNest({
    required this.row,
    required this.col,
    this.health = nestMaxHealth,
    this.spawnCooldown = 0,
  });

  final int row;
  final int col;
  final int health;
  final int spawnCooldown;

  EnemyNest copyWith({
    int? health,
    int? spawnCooldown,
  }) {
    return EnemyNest(
      row: row,
      col: col,
      health: health ?? this.health,
      spawnCooldown: spawnCooldown ?? this.spawnCooldown,
    );
  }
}

@immutable
class Enemy {
  const Enemy({
    required this.id,
    required this.position,
    this.health = enemyMaxHealth,
    this.path = const [],
  });

  final int id;
  final (double, double) position; // Use double for smoother movement
  final int health;
  final List<(int, int)> path;

  Enemy copyWith({
    (double, double)? position,
    int? health,
    List<(int, int)>? path,
    bool clearPath = false,
  }) {
    return Enemy(
      id: id,
      position: position ?? this.position,
      health: health ?? this.health,
      path: clearPath ? [] : path ?? this.path,
    );
  }
}