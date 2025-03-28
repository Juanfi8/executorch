# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

import itertools

import logging
from typing import List, Optional, Type, Union

from executorch.backends.xnnpack.partition.config import ALL_PARTITIONER_CONFIGS
from executorch.backends.xnnpack.partition.config.xnnpack_config import (
    ConfigPrecisionType,
    XNNPartitionerConfig,
)

from executorch.backends.xnnpack.xnnpack_preprocess import XnnpackBackend
from executorch.exir.backend.backend_details import ExportedProgram
from executorch.exir.backend.canonical_partitioners.config_partitioner import (
    ConfigerationBasedPartitioner,
)
from executorch.exir.backend.partitioner import DelegationSpec
from torch.fx.passes.infra.partitioner import Partition

logging.basicConfig(level=logging.WARNING)
logger = logging.getLogger(__name__)


class XnnpackPartitioner(ConfigerationBasedPartitioner):
    def __init__(
        self,
        configs: Optional[List[Type[XNNPartitionerConfig]]] = None,
        config_precisions: Optional[
            Union[ConfigPrecisionType, List[ConfigPrecisionType]]
        ] = None,
        per_op_mode=False,
        verbose: bool = False,
        **kwargs,
    ):
        """
        @verbose: if True, print out more information about the partitioner.
            Default level is WARNING. If verbose is True, level is set to DEBUG.
        """
        if verbose:
            logger.setLevel(logging.DEBUG)
            logger.debug("Verbose logging enabled for XNNPACK partitioner.")

        delegation_spec = DelegationSpec(XnnpackBackend.__name__, [])
        configs_to_use = configs or ALL_PARTITIONER_CONFIGS
        # Can do logic and have extra args to filter/delete/select
        # Certain configs based on user specification
        initialized_configs = []
        if isinstance(config_precisions, ConfigPrecisionType):
            config_precisions = [config_precisions]

        for config in configs_to_use:
            # Config Classes given to XnnpackPartitioner should no longer be abstract
            initialized = config(**kwargs)  #  pyre-ignore
            initialized.set_enabled_precision_types(config_precisions)
            initialized_configs.append(initialized)

        # per_op_mode takes the first match from a partitioner config, any
        # subsequent matches that overlap with the first match are not partitioned
        self.per_op_mode = per_op_mode
        super().__init__(delegation_spec, initialized_configs)

    def generate_partitions(self, ep: ExportedProgram) -> List[Partition]:
        """
        generate_partitions is different if partitioner is set to per_op_mode
        for per_op_mode we only need to generate unmerged partitions instead
        of using the default generate_partitions method.
        """
        if self.per_op_mode:
            return self.generate_per_op_partitions(ep)
        else:
            return super().generate_partitions(ep)

    def generate_per_op_partitions(self, ep: ExportedProgram) -> List[Partition]:
        """
        Uses configs to generate per_op_partitions. That is no partitions are
        merged together. All partitions (node + deps) returned by PartitionerConfigs
        are put into their own partition.
        """
        partitions = []
        matched_nodes = self.get_matched_nodes_from_configs(ep)
        partition_id = itertools.count()
        nodes_seen = {}
        for match in matched_nodes:
            # for debug information we map the node to the string form
            # of the partition it belongs to
            match_map = dict.fromkeys(match, str(match))
            # We only create partitions from the first PartitionerConfig match
            # if a subsequent partitioner match contains the same node, we do
            # not create a partition for it
            overlap = match_map.keys() & nodes_seen.keys()
            if len(overlap) == 0:
                partitions.append(
                    Partition(
                        id=next(partition_id),
                        nodes=match_map.keys(),
                    )
                )
                nodes_seen.update(match_map)
            else:
                error_str = f"per_op mode expects no overlaps between partitions but the partition {match_map.keys()} overlaps with the following partitions:\n"
                for overlap_node in overlap:
                    error_str += f"{nodes_seen[overlap_node]}\n"

                raise RuntimeError(error_str)

        return partitions


class XnnpackDynamicallyQuantizedPartitioner(XnnpackPartitioner):
    def __init__(self):
        super().__init__(
            config_precisions=ConfigPrecisionType.DYNAMIC_QUANT,
        )


class XnnpackFloatingPointPartitioner(XnnpackPartitioner):
    def __init__(self):
        super().__init__(config_precisions=ConfigPrecisionType.FP32)


class XnnpackQuantizedPartitioner(XnnpackPartitioner):
    def __init__(self):
        super().__init__(config_precisions=ConfigPrecisionType.STATIC_QUANT)
