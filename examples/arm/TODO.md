# Files to modify are:

## Required 
- [ ] examples/arm/executor_runner/CMakeLists.txt
- [ ] examples/arm/executor_runner/arm_executor_runner.cpp
- [ ] Add file for stm target library, linker, sdk etc

## For better integration 
- [ ] The run.sh file 
- [ ] backends/arm/scripts/build_executorch_runner.sh
- [x] python3 -m examples.arm.aot_arm_compiler

## Already modified
- [ ]examples/arm/ethos-u-setup/arm-none-eabi-gcc.cmake 

## Fixes
- [x]Add support for other system configurations
- [x]Add support for other memory modes
- [x]Add support for other targets


#########################
The run.sh script takes --target as an argument. The target are defined on the 
aot_arm_compiler.py file. Targets are: 

'''
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
]
'''

This targets are only used if we use the `delegate` flag. The delegate flag is used to
call the `to_edge_TOSA_delegate` function. In the function it is used to call the 
`get_compile_spec` function which handles logic for the target. The target is then used to 
choose the Partitioner and run `to_edge_transform_and_lower` with the appropiate
partitioner.

Not using a valid target will result an error message in the `get_args` function 
because we need the `memory_mode` and `system_config` to be defined and the logic is valid only for 
the targets defined above.