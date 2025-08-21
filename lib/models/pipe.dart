import 'package:factory_sim/models/conveyor.dart';
import 'package:factory_sim/models/resource.dart';
import 'package:flutter/foundation.dart';

const int pipeCapacity = 100;

@immutable
class Pipe {
  const Pipe({
    required this.direction,
    required this.row,
    required this.col,
    this.fluid,
    this.fluidAmount = 0,
  });

  final Direction direction;
  final int row;
  final int col;
  final ResourceType? fluid;
  final int fluidAmount;

  Pipe copyWith({
    Direction? direction,
    int? row,
    int? col,
    ResourceType? fluid,
    bool clearFluid = false,
    int? fluidAmount,
  }) {
    return Pipe(
      direction: direction ?? this.direction,
      row: row ?? this.row,
      col: col ?? this.col,
      fluid: clearFluid ? null : fluid ?? this.fluid,
      fluidAmount: clearFluid ? 0 : fluidAmount ?? this.fluidAmount,
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Pipe && runtimeType == other.runtimeType && direction == other.direction && row == other.row && col == other.col && fluid == other.fluid && fluidAmount == other.fluidAmount;

  @override
  int get hashCode => direction.hashCode ^ row.hashCode ^ col.hashCode ^ fluid.hashCode ^ fluidAmount.hashCode;
}