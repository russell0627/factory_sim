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
  MachineType.copperMiner: {
    ResourceType.ironPlate: 10,
  },
  MachineType.coalGenerator: {
    ResourceType.ironPlate: 40,
  },
  MachineType.powerPole: {
    ResourceType.copperWire: 2,
  },
  MachineType.droneStation: {
    ResourceType.ironPlate: 50,
    ResourceType.circuit: 20,
  },
  MachineType.trainStop: {
    ResourceType.ironPlate: 50,
    ResourceType.circuit: 25,
  },
  MachineType.offshorePump: {
    ResourceType.ironPlate: 15,
    ResourceType.circuit: 5,
  },
  MachineType.oilDerrick: {
    ResourceType.ironPlate: 30,
    ResourceType.circuit: 15,
  },
  MachineType.refinery: {
    ResourceType.ironPlate: 50,
    ResourceType.circuit: 25,
  },
  MachineType.chemicalPlant: {
    ResourceType.ironPlate: 40,
    ResourceType.circuit: 20,
  },

  // Tier 2
  MachineType.coalMinerT2: {
    ResourceType.ironPlate: 30,
  },
  MachineType.minerT2: {
    ResourceType.ironPlate: 30,
  },
  MachineType.copperMinerT2: {
    ResourceType.ironPlate: 30,
  },
  MachineType.smelterT2: {
    ResourceType.ironPlate: 50,
  },
  MachineType.assemblerT2: {
    ResourceType.ironPlate: 40,
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

final Map<ResourceType, int> pipeCost = {
  ResourceType.ironPlate: 1,
};

final Map<ResourceType, int> railCost = {
  ResourceType.ironPlate: 1,
};