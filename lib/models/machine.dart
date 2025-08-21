import 'package:factory_sim/models/resource.dart';

/// Enum for all types of machines in the game.
enum MachineType {
  miner,
  smelter,
  assembler,
}

/// Represents a machine placed on the game grid.
class Machine {
  const Machine({
    required this.type,
    required this.row,
    required this.col,
    this.outputBuffer,
    this.productionProgress = 0,
  });

  final MachineType type;
  final int row;
  final int col;

  /// A single slot to hold a completed item before it's ejected.
  final ResourceType? outputBuffer;

  /// Tracks the progress of the current production cycle.
  final int productionProgress;

  Machine copyWith({
    MachineType? type,
    int? row,
    int? col,
    ResourceType? outputBuffer,
    bool clearOutputBuffer = false,
    int? productionProgress,
  }) {
    return Machine(
      type: type ?? this.type,
      row: row ?? this.row,
      col: col ?? this.col,
      outputBuffer: clearOutputBuffer ? null : outputBuffer ?? this.outputBuffer,
      productionProgress: productionProgress ?? this.productionProgress,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Machine && runtimeType == other.runtimeType && type == other.type && row == other.row && col == other.col && outputBuffer == other.outputBuffer && productionProgress == other.productionProgress;

  @override
  int get hashCode => type.hashCode ^ row.hashCode ^ col.hashCode ^ outputBuffer.hashCode ^ productionProgress.hashCode;
}