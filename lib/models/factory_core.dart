import 'package:factory_sim/models/resource.dart';
import 'package:flutter/foundation.dart';

const int factoryCoreSize = 3;

final Map<ResourceType, int> factoryCorePlacementCost = {
  ResourceType.ironPlate: 250,
  ResourceType.circuit: 50,
};

final List<Map<ResourceType, int>> factoryCorePhaseRequirements = [
  // Phase 1
  {ResourceType.ironPlate: 1000},
  // Phase 2
  {ResourceType.copperPlate: 1000},
  // Phase 3
  {ResourceType.circuit: 500},
];

@immutable
class FactoryCoreState {
  const FactoryCoreState({
    required this.row,
    required this.col,
    this.phase = 0,
    this.progress = const {},
    this.isComplete = false,
  });

  final int row;
  final int col;
  final int phase;
  final Map<ResourceType, int> progress;
  final bool isComplete;

  FactoryCoreState copyWith({
    int? row,
    int? col,
    int? phase,
    Map<ResourceType, int>? progress,
    bool? isComplete,
  }) {
    return FactoryCoreState(
      row: row ?? this.row,
      col: col ?? this.col,
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FactoryCoreState &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col &&
          phase == other.phase &&
          progress == other.progress &&
          isComplete == other.isComplete;

  @override
  int get hashCode => row.hashCode ^ col.hashCode ^ phase.hashCode ^ progress.hashCode ^ isComplete.hashCode;
}