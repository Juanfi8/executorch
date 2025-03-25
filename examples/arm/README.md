# ExecuTorch on ARM Cortex-M55 + Ethos-U55 NPU | Corstone-300 FVP

This dir contains scripts to help you prepare setup needed to run a PyTorch
model on an ARM Corstone-300 platform via ExecuTorch. 
The Corstone-300 platform simulates the Cortex-M55 CPU and Ethos-U55 NPU.

There are two main scripts, "setup.sh" and "run.sh". Each takes one optional,
positional argument. It is a path to a scratch dir to download and generate
build artifacts. If supplied, the same argument must be supplied to both the scripts.
Default scrach dir is `executorch/examples/arm/ethos-u-scratch`.

## Overview

1) We will start from a PyTorch model in python, export it, convert it to a `.pte`
file - A binary format adopted by ExecuTorch.

2) Then we will take the `.pte` model file and embed that with a baremetal 
application executor_runner. 

3) We will then take the executor_runner file, which  contains not only the 
`.pte` file but also necessary software component (executorch runtime) to run 
standalone on a baremetal system.

4) (Optional) Lastly, we will run the executor_runner binary on a Corstone-300 FVP Simulator
platform.

## Prerequisites

1) You need to have a working internet connection to download necessary tools.

2) You need to have a Linux system to run these scripts. Tested on Ubuntu 22.04.

3) Run the `setup.sh` script to download necessary tools and setup the environment:

```
$ cd <EXECUTORCH-ROOT-FOLDER>
$ executorch/examples/arm/setup.sh --i-agree-to-the-contained-eula [optional-scratch-dir]
```

## Directory Structure

The directory structure after running the `setup.sh` script should look like this:

```
executorch/examples/arm/
├── ethos-u-scratch
│   ├── arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-eabi
│   ├── ethos-u
│   ├── ethos_u
│   ├── ethos_u-subbuild
│   ├── FVP-corstone300
│   ├── FVP-corstone320
│   ├── arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-eabi.tar.xz
│   ├── FVP_corstone300.tgz
│   ├── FVP_corstone320.tgz
│   └── setup_path.sh
├── ethos-u-setup
│   ├── core_platform
│   └── arm-none-eabi-gcc.cmake
├── executor_runner
│   ├── arm_executor_runner.cpp
│   ├── arm_perf_monitor.cpp
│   ├── arm_perf_monitor.h
│   ├── CMakeLists.txt
│   └── pte_to_header.py
├── aot_arm_compiler.py # Script to compile a PyTorch model to .pte file
├── CMakeLists.txt
├── README.md
├── run.sh # Script to build and run the executor_runner baremetal application
└── setup.sh #Setup script to download necessary tools and setup the environment
```


## Example Usage

```
# Build + run ExecuTorch and executor_runner baremetal application
# Suited for Corstone FVP's to run a simple PyTorch model.
$ executorch/examples/arm/run.sh [--scratch-dir=same-optional-scratch-dir-as-before]
```
This script by default will build and run 4 different models on the Corstone-300 FVP platform:
- `softmax`
- `add`
- `add3`
- `mv2`

# Running custom models on different platforms

Once, you have successfully run the above scripts, you can try running your own 
custom models on the Corstone-300 FVP platform or any other platform supported by
ExecuTorch.

## Build and run a custom executorch model

1) Create a new directory in `executorch/examples/models/` with the name of your model.

2) Create a new file `model.py` and `__init.py__` in the directory and follow the `model_base.py`
to create the custom class required by the `run.sh` and `aot_compiler.py` scripts. For reference, 
you can imitate the simple `torchvision_vit` or `simple_transformer` directory structure.

3) Add the newly created model to the `__init__.py` file in `executorch/examples/models/` 
directory:

```python
MODEL_NAME_TO_MODEL = {
    "custom_model_name": ("custom_model_directory", "customModelClassName"),
    (...)
}
```
4) Run the `run.sh` script with the `--model_name` flag to run the custom model:

```
$ executorch/examples/arm/run.sh --model_name=custom_model_name [--scratch-dir=same-optional-scratch-dir-as-before]
```
Additional flags can be passed to the `run.sh` script to customize the build and run process. 

None delegated operators (portable kernels from the ATen library) can be included 
with the `--portable_kernels` flag. The complete summary of required operators can be found in the
`executorch/arm_test/model/delegation_info.txt` file.

For more information, see the next section.

## Additonal flags for `run.sh` script

```
$ executorch/examples/arm/run.sh --help
Usage: run.sh [OPTIONS]
Options:
  --model_name=<MODEL>                   Model file .py/.pth/.pt, builtin model or a model from examples/models. Passed to aot_arm_compiler
  --model_input=<INPUT>                  Provide model input .pt file to override the input in the model file. Passed to aot_arm_compiler
                                           NOTE: Inference in FVP is done with a dummy input full of ones. Use bundleio flag to run the model in FVP with the custom input or the input from the model file.
  --aot_arm_compiler_flags=<FLAGS>       Only used if --model_name is used Default: --delegate --quantize
  --portable_kernels=<OPS>               Comma separated list of portable (non delagated) kernels to include Default: aten::_softmax.out
  --target=<TARGET>                      Target to build and run for Default: ethos-u55-128
  --output=<FOLDER>                      Target build output folder Default: .
  --bundleio                             Create Bundled pte using Devtools BundelIO with Input/RefOutput included
  --etdump                               Adds Devtools etdump support to track timing, etdump area will be base64 encoded in the log
  --build_type=<TYPE>                    Build with Release, Debug or RelWithDebInfo, default is Release
  --extra_build_flags=<FLAGS>            Extra flags to pass to cmake like -DET_ARM_BAREMETAL_METHOD_ALLOCATOR_POOL_SIZE=60000 Default: none
  --build_only                           Only build, don't run FVP
  --system_config=<CONFIG>               System configuration to select from the Vela configuration file (see vela.ini). Default: Ethos_U55_High_End_Embedded for EthosU55 targets, Ethos_U85_SYS_DRAM_Mid for EthosU85 targets.
                                            NOTE: If given, this option must match the given target. This option also sets timing adapter values customized for specific hardware, see ./executor_runner/CMakeLists.txt.
  --memory_mode=<MODE>                   Memory mode to select from the Vela configuration file (see vela.ini), e.g. Shared_Sram/Sram_Only. Default: 'Shared_Sram' for Ethos-U55 targets, 'Sram_Only' for Ethos-U85 targets
  --et_build_root=<FOLDER>               Executorch build output root folder to use, defaults to /home/juan/execuTorch/executorch/arm_test
  --scratch-dir=<FOLDER>                 Path to your Ethos-U scrach dir if you not using default /home/juan/execuTorch/executorch/examples/arm/ethos-u-scratch
```



## Build on a different platform

TODO


# Online  Tutorial

We also have a [tutorial](https://pytorch.org/executorch/stable/executorch-arm-delegate-tutorial.html) 
explaining the steps performed in these scripts, expected results, possible problems and more.
It is a step-by-step guide you can follow to better understand this delegate.
