import 'package:factory_sim/models/resource.dart';

/// The direction a conveyor belt is facing.
enum Direction {
  up,
  down,
  left,
  right,
}

/// Represents a single conveyor belt tile on the grid.
class Conveyor {
  const Conveyor({
    required this.row,
    required this.col,
    required this.direction,
    this.resource,
  });

  final int row;
  final int col;
  final Direction direction;

  /// The resource currently on this conveyor belt tile.
  /// A null value means the belt is empty.
  final ResourceType? resource;

  Conveyor copyWith({
    int? row,
    int? col,
    Direction? direction,
    ResourceType? resource,
    bool clearResource = false,
  }) {
    return Conveyor(
      row: row ?? this.row,
      col: col ?? this.col,
      direction: direction ?? this.direction,
      resource: clearResource ? null : resource ?? this.resource,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conveyor && runtimeType == other.runtimeType && row == other.row && col == other.col && direction == other.direction && resource == other.resource;

  @override
  int get hashCode => row.hashCode ^ col.hashCode ^ direction.hashCode ^ resource.hashCode;
}