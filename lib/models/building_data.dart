import 'package:factory_sim/models/machine.dart';
import 'package:factory_sim/models/resource.dart';

/// Defines the resource cost to build a machine.
final Map<MachineType, Map<ResourceType, int>> machineCosts = {
  MachineType.miner: {
    ResourceType.ironPlate: 10,
  },
  MachineType.smelter: {
    ResourceType.ironPlate: 20,
  },
  MachineType.assembler: {
    ResourceType.ironPlate: 30,
    ResourceType.copperPlate: 15,
  },
};

/// Defines the resource cost to build a single conveyor belt.
final Map<ResourceType, int> conveyorCost = {
  ResourceType.ironPlate: 1,
};