# Files to modify for Cortex M33 support

## Required 
- [ ] examples/arm/executor_runner/CMakeLists.txt
- [ ] examples/arm/executor_runner/arm_executor_runner.cpp
- [x] Toolchain_cmake examples/arm/ethos-u-setup/arm-none-eabi-gcc.cmake
- [ ] The run.sh file 
- [ ] backends/arm/scripts/build_executorch_runner.sh
- [x] python3 -m examples.arm.aot_arm_compiler

## Check 
- [x]Add support for other system configurations
- [x]Add support for other memory modes
- [x]Add support for other targets
- [ ] Add file for stm target library, linker, sdk etc
----------------------------------

The run.sh script takes --target as an argument. The target are defined on the 
aot_arm_compiler.py file. 


## aot_arm_compiler.py modifications

Targets are: 

```
targets = [
    "ethos-u55-32",
    "ethos-u55-64",
    "ethos-u55-128",
    "ethos-u55-256",
    "ethos-u85-128",
    "ethos-u85-256",
    "ethos-u85-512",
    "ethos-u85-1024",
    "ethos-u85-2048",
    "TOSA",
    "cortex-m33",
]
```

This targets are only used if we use the `delegate` flag. The delegate flag is used to
call the `to_edge_TOSA_delegate` function. In the function it is used to call the 
`get_compile_spec` function which handles logic for the target. The target is then used to 
choose the Partitioner and run `to_edge_transform_and_lower` with the appropiate
partitioner.

The `memory_mode` and `system_config` are used to choose the correct partitioner 
when the `delegate` flag is used. When the `delegate` flag is not used, there is 
no need to specify the target.This could cause problems in the long run.

Modifications: 
Add cortex-m33 as a target and added logic to verify the passed target
is valid. 

## Run.sh

For the run.sh script, we need to add the logic for the cortex-m33 target. We set
2 flags `system_config` and `memory_mode` if the target is the cortex-m33. These 
flags are then given to `build_executorch_runner.sh`.

## build_executorch_runner.sh

This file is used to build the executor runner. It passes some flags to the cmake
in the `executor_runner` folder and then builds the executor runner. 

We added the logic for the m33 target for the file but we have to also edit it in the 
CMake file.

## arm-none-eabi-gcc.cmake

This cmake file is a toolchain file for the build_executor_runner.sh script. it 
allows to set some variables for the build (c version, the compiler, etc).It already
handles the logic for the cortex m-33.

There is no apparent need to modify this file. It already handles the logic for the cortex m-33 
logic.