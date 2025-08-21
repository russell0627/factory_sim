import 'package:flutter/foundation.dart';

enum TrainStopMode { load, unload }

@immutable
class TrainStopData {
  const TrainStopData({
    this.stationName = 'New Stop',
    this.mode = TrainStopMode.load,
  });

  final String stationName;
  final TrainStopMode mode;

  TrainStopData copyWith({
    String? stationName,
    TrainStopMode? mode,
  }) {
    return TrainStopData(
      stationName: stationName ?? this.stationName,
      mode: mode ?? this.mode,
    );
  }
}