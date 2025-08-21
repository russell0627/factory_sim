import 'package:factory_sim/models/recipe.dart';
import 'package:factory_sim/models/resource.dart';
import 'package:flutter/foundation.dart';

const int playerEquipmentSlots = 4;

@immutable
class Player {
  const Player({
    required this.position,
    this.equipment = const [],
    this.craftingQueue = const [],
    this.craftingProgress = 0,
  });

  final (int, int) position; // (col, row)
  final List<ResourceType> equipment;
  final List<Recipe> craftingQueue;
  final int craftingProgress;

  Player copyWith({
    (int, int)? position,
    List<ResourceType>? equipment,
    List<Recipe>? craftingQueue,
    int? craftingProgress,
    bool clearCrafting = false,
  }) {
    return Player(
      position: position ?? this.position,
      equipment: equipment ?? this.equipment,
      craftingQueue: clearCrafting ? [] : craftingQueue ?? this.craftingQueue,
      craftingProgress: clearCrafting ? 0 : craftingProgress ?? this.craftingProgress,
    );
  }
}