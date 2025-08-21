import 'package:factory_sim/models/machine.dart';
import 'package:factory_sim/models/resource.dart';

/// Defines the resource cost to build a machine.
final Map<MachineType, Map<ResourceType, int>> machineCosts = {
  MachineType.coalMiner: {
    ResourceType.ironPlate: 10,
  },
  MachineType.miner: {
    ResourceType.ironPlate: 10,
  },
  MachineType.smelter: {
    ResourceType.ironPlate: 20,
  },
  MachineType.assembler: {
    ResourceType.ironPlate: 10, // Requires some initial plates as well
  },
  MachineType.storage: {
    ResourceType.ironPlate: 20,
  },
  MachineType.grinder: {
    ResourceType.ironPlate: 15,
  },
};

/// Defines the resource cost to build a single conveyor belt.
final Map<ResourceType, int> conveyorCost = {
  ResourceType.ironPlate: 1,
};

/// Defines the resource cost to build a single conveyor splitter.
final Map<ResourceType, int> conveyorSplitterCost = {
  ResourceType.ironPlate: 5,
};

/// Defines the resource cost to build a single conveyor merger.
final Map<ResourceType, int> conveyorMergerCost = {
  ResourceType.ironPlate: 5,
};