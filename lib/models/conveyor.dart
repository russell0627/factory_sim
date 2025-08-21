import 'package:factory_sim/models/resource.dart';

/// The direction a conveyor belt is facing.
enum Direction {
  up,
  down,
  left,
  right,
}

enum ConveyorType {
  normal,
  splitter,
  merger,
}

/// Represents a single conveyor belt tile on the grid.
class Conveyor {
  const Conveyor({
    required this.row,
    required this.col,
    required this.direction,
    this.type = ConveyorType.normal,
    this.resource,
    this.splitterToggle = 0,
  });

  final int row;
  final int col;
  final Direction direction;
  final ConveyorType type;

  /// The resource currently on this conveyor belt tile.
  /// A null value means the belt is empty.
  final ResourceType? resource;

  /// A toggle used by splitters to alternate outputs.
  final int splitterToggle;

  Conveyor copyWith({
    int? row,
    int? col,
    Direction? direction,
    ConveyorType? type,
    ResourceType? resource,
    bool clearResource = false,
    int? splitterToggle,
  }) {
    return Conveyor(
      row: row ?? this.row,
      col: col ?? this.col,
      direction: direction ?? this.direction,
      type: type ?? this.type,
      resource: clearResource ? null : resource ?? this.resource,
      splitterToggle: splitterToggle ?? this.splitterToggle,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conveyor &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col &&
          direction == other.direction &&
          type == other.type &&
          resource == other.resource &&
          splitterToggle == other.splitterToggle;

  @override
  int get hashCode => row.hashCode ^ col.hashCode ^ direction.hashCode ^ type.hashCode ^ resource.hashCode ^ splitterToggle.hashCode;
}