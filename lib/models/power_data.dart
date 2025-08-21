import 'package:factory_sim/models/machine.dart';

/// Power consumption in MW for each machine type.
final Map<MachineType, int> powerConsumption = {
  // Miners
  MachineType.coalMiner: 5,
  MachineType.miner: 5,
  MachineType.copperMiner: 5,
  MachineType.coalMinerT2: 10,
  MachineType.minerT2: 10,
  MachineType.copperMinerT2: 10,

  // Production
  MachineType.smelter: 10,
  MachineType.assembler: 15,
  MachineType.smelterT2: 20,
  MachineType.assemblerT2: 30,

  // Other
  MachineType.grinder: 5,
  MachineType.storage: 1,
  MachineType.powerPole: 1,
};

/// Power generation in MW for each generator type.
final Map<MachineType, int> powerGeneration = {
  MachineType.coalGenerator: 30,
};