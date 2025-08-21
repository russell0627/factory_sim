import 'package:factory_sim/models/resource.dart';
import 'package:factory_sim/models/drone.dart';
import 'package:factory_sim/models/turret_data.dart';
import 'package:factory_sim/models/train_stop_data.dart';
import 'package:factory_sim/models/conveyor.dart';

/// Enum for all types of machines in the game.
enum MachineType {
  coalMiner,
  miner,
  coalGenerator,
  copperMiner,
  powerPole,
  smelter,
  refinery,
  chemicalPlant,
  offshorePump,
  oilDerrick,
  assembler,
  wall,
  gunTurret,
  droneStation,
  trainStop,
  storage,
  grinder,
  // Tier 2
  coalMinerT2,
  minerT2,
  copperMinerT2,
  smelterT2,
  assemblerT2,
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
    this.fluidInputBuffer = const {},
    this.fluidOutputBuffer = const {},
    this.isPowered = true,
    this.droneStationData,
    this.trainStopData,
    this.health = 100, // Default health
    this.turretData,
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

  /// A buffer to hold input fluids before production begins.
  final Map<ResourceType, int> fluidInputBuffer;

  /// A buffer to hold output fluids before they are ejected.
  final Map<ResourceType, int> fluidOutputBuffer;

  /// Whether the machine has enough power to operate this tick.
  final bool isPowered;

  /// Specific data for drone stations, if applicable.
  final DroneStationData? droneStationData;

  /// Specific data for train stops, if applicable.
  final TrainStopData? trainStopData;

  /// Current health of the machine.
  final int health;

  /// Specific data for turrets, if applicable.
  final TurretData? turretData;

  Machine copyWith({
    MachineType? type,
    int? row,
    int? col,
    Direction? direction,
    Map<ResourceType, int>? inputBuffer,
    ResourceType? outputBuffer,
    ResourceType? configuredOutput,
    bool clearOutputBuffer = false,
    Map<ResourceType, int>? fluidInputBuffer,
    Map<ResourceType, int>? fluidOutputBuffer,
    int? productionProgress,
    bool? isPowered,
    DroneStationData? droneStationData,
    TrainStopData? trainStopData,
    int? health,
    TurretData? turretData,
  }) {
    return Machine(
      type: type ?? this.type,
      row: row ?? this.row,
      col: col ?? this.col,
      direction: direction ?? this.direction,
      inputBuffer: inputBuffer ?? this.inputBuffer,
      outputBuffer: clearOutputBuffer ? null : outputBuffer ?? this.outputBuffer,
      configuredOutput: configuredOutput ?? this.configuredOutput,
      fluidInputBuffer: fluidInputBuffer ?? this.fluidInputBuffer,
      fluidOutputBuffer: fluidOutputBuffer ?? this.fluidOutputBuffer,
      productionProgress: productionProgress ?? this.productionProgress,
      isPowered: isPowered ?? this.isPowered,
      droneStationData: droneStationData ?? this.droneStationData,
      trainStopData: trainStopData ?? this.trainStopData,
      health: health ?? this.health,
      turretData: turretData ?? this.turretData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Machine && runtimeType == other.runtimeType && type == other.type && row == other.row && col == other.col && direction == other.direction && inputBuffer == other.inputBuffer && outputBuffer == other.outputBuffer && configuredOutput == other.configuredOutput && productionProgress == other.productionProgress && fluidInputBuffer == other.fluidInputBuffer && fluidOutputBuffer == other.fluidOutputBuffer && isPowered == other.isPowered && droneStationData == other.droneStationData && trainStopData == other.trainStopData && health == other.health && turretData == other.turretData;

  @override
  int get hashCode => type.hashCode ^ row.hashCode ^ col.hashCode ^ direction.hashCode ^ inputBuffer.hashCode ^ outputBuffer.hashCode ^ configuredOutput.hashCode ^ productionProgress.hashCode ^ fluidInputBuffer.hashCode ^ fluidOutputBuffer.hashCode ^ isPowered.hashCode ^ droneStationData.hashCode ^ trainStopData.hashCode ^ health.hashCode ^ turretData.hashCode;
}