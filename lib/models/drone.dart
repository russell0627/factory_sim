import 'package:factory_sim/models/resource.dart';
import 'package:flutter/foundation.dart';

/// The cost to build a single drone.
final Map<ResourceType, int> droneCost = {
  ResourceType.circuit: 10,
  ResourceType.ironPlate: 20,
};

enum DroneStatus { idle, exploring }

@immutable
class Drone {
  const Drone({
    this.status = DroneStatus.idle,
    this.ticksRemaining = 0,
  });

  final DroneStatus status;
  final int ticksRemaining;

  Drone copyWith({
    DroneStatus? status,
    int? ticksRemaining,
  }) {
    return Drone(
      status: status ?? this.status,
      ticksRemaining: ticksRemaining ?? this.ticksRemaining,
    );
  }
}

/// Represents the state of a single Drone Station machine.
@immutable
class DroneStationData {
  const DroneStationData({
    this.drones = const [],
  });

  final List<Drone> drones;

  DroneStationData copyWith({
    List<Drone>? drones,
  }) {
    return DroneStationData(
      drones: drones ?? this.drones,
    );
  }
}