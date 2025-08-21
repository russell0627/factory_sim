import 'package:factory_sim/models/resource.dart';
import 'package:flutter/foundation.dart';

const int wagonCapacity = 50;

enum TrainStatus { idleAtStation, movingToStation, waitingForLoad, waitingForUnload }

@immutable
class TrainScheduleStop {
  const TrainScheduleStop({required this.stationName});
  final String stationName;
}

@immutable
class CargoWagon {
  const CargoWagon({this.resource, this.amount = 0});
  final ResourceType? resource;
  final int amount;

  CargoWagon copyWith({ResourceType? resource, int? amount, bool clearResource = false}) {
    return CargoWagon(
      resource: clearResource ? null : resource ?? this.resource,
      amount: amount ?? this.amount,
    );
  }
}

@immutable
class Train {
  const Train({
    required this.id,
    required this.locomotivePosition,
    this.wagons = const [CargoWagon(), CargoWagon()], // Start with 2 wagons
    this.schedule = const [],
    this.currentScheduleIndex = 0,
    this.currentPath = const [],
    this.status = TrainStatus.idleAtStation,
    this.ticksToWait = 0,
  });

  final int id;
  final (int, int) locomotivePosition;
  final List<CargoWagon> wagons;
  final List<TrainScheduleStop> schedule;
  final int currentScheduleIndex;
  final List<(int, int)> currentPath;
  final TrainStatus status;
  final int ticksToWait;

  Train copyWith({
    (int, int)? locomotivePosition,
    List<CargoWagon>? wagons,
    List<TrainScheduleStop>? schedule,
    int? currentScheduleIndex,
    List<(int, int)>? currentPath,
    bool clearPath = false,
    TrainStatus? status,
    int? ticksToWait,
  }) {
    return Train(
      id: id,
      locomotivePosition: locomotivePosition ?? this.locomotivePosition,
      wagons: wagons ?? this.wagons,
      schedule: schedule ?? this.schedule,
      currentScheduleIndex: currentScheduleIndex ?? this.currentScheduleIndex,
      currentPath: clearPath ? [] : currentPath ?? this.currentPath,
      status: status ?? this.status,
      ticksToWait: ticksToWait ?? this.ticksToWait,
    );
  }
}