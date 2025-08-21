import 'package:factory_sim/models/resource.dart';
import 'package:factory_sim/models/conveyor.dart';

/// Enum for all types of machines in the game.
enum MachineType {
  coalMiner,
  miner,
  smelter,
  assembler,
  storage,
  grinder,
}

/// Represents a machine placed on the game grid.
class Machine {
  const Machine({
    required this.type,
    required this.row,
    required this.col,
    this.direction = Direction.down,
    this.inputBuffer = const {},
    this.outputBuffer,
    this.configuredOutput,
    this.productionProgress = 0,
  });

  final MachineType type;
  final int row;
  final int col;
  final Direction direction;

  /// A buffer to hold input resources before production begins.
  final Map<ResourceType, int> inputBuffer;

  /// A single slot to hold a completed item before it's ejected.
  final ResourceType? outputBuffer;

  /// For storage buildings, which resource to pull from global inventory for output.
  final ResourceType? configuredOutput;

  /// Tracks the progress of the current production cycle.
  final int productionProgress;

  Machine copyWith({
    MachineType? type,
    int? row,
    int? col,
    Direction? direction,
    Map<ResourceType, int>? inputBuffer,
    ResourceType? outputBuffer,
    ResourceType? configuredOutput,
    bool clearOutputBuffer = false,
    int? productionProgress,
  }) {
    return Machine(
      type: type ?? this.type,
      row: row ?? this.row,
      col: col ?? this.col,
      direction: direction ?? this.direction,
      inputBuffer: inputBuffer ?? this.inputBuffer,
      outputBuffer: clearOutputBuffer ? null : outputBuffer ?? this.outputBuffer,
      configuredOutput: configuredOutput ?? this.configuredOutput,
      productionProgress: productionProgress ?? this.productionProgress,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Machine && runtimeType == other.runtimeType && type == other.type && row == other.row && col == other.col && direction == other.direction && inputBuffer == other.inputBuffer && outputBuffer == other.outputBuffer && configuredOutput == other.configuredOutput && productionProgress == other.productionProgress;

  @override
  int get hashCode => type.hashCode ^ row.hashCode ^ col.hashCode ^ direction.hashCode ^ inputBuffer.hashCode ^ outputBuffer.hashCode ^ configuredOutput.hashCode ^ productionProgress.hashCode;
}