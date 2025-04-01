#!/usr/bin/env bash
# Copyright 2025 Arm Limited and/or its affiliates.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

set -eu

script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
et_root_dir=$(cd ${script_dir}/../../.. && pwd)
et_root_dir=$(realpath ${et_root_dir})
toolchain_cmake=${et_root_dir}/examples/arm/ethos-u-setup/arm-none-eabi-gcc.cmake 
setup_path_script=${et_root_dir}/examples/arm/ethos-u-scratch/setup_path.sh #TODO 
_setup_msg="please refer to ${et_root_dir}/examples/arm/setup.sh to properly install necessary tools."

pte_file=""
target="ethos-u55-128"
build_type="Release"
bundleio=false
system_config=""
memory_mode=""
build_with_etdump=false
extra_build_flags=""
output_folder_set=false
output_folder="."
et_build_root="${et_root_dir}/arm_test"
ethosu_tools_dir=${et_root_dir}/examples/arm/ethos-u-scratch
flash=false

build_bundleio_flags=" -DET_BUNDLE_IO=OFF "
build_with_etdump_flags=" -DEXECUTORCH_ENABLE_EVENT_TRACER=OFF "

help() {
    echo "Usage: $(basename $0) [options]"
    echo "Options:"
    echo "  --pte=<PTE_FILE>                pte file (genrated by the aot_arm_compier from the model to include in the elf"
    echo "  --target=<TARGET>               Target to build and run for Default: ${target}"
    echo "  --build_type=<TYPE>             Build with Release, Debug or RelWithDebInfo, default is ${build_type}"
    echo "  --bundleio                      Support both pte and Bundle IO bpte using Devtools BundelIO with Input/RefOutput included"
    echo "  --system_config=<CONFIG>        System configuration to select from the Vela configuration file (see vela.ini). Default: Ethos_U55_High_End_Embedded for EthosU55 targets, Ethos_U85_SYS_DRAM_Mid for EthosU85 targets."
    echo "                                     NOTE: If given, this option must match the given target. This option along with the memory_mode sets timing adapter values customized for specific hardware, see ./executor_runner/CMakeLists.txt."
    echo "  --memory_mode=<CONFIG>          Vela memory mode, used for setting the Timing Adapter parameters of the Corstone platforms."
    echo "                                  Valid values are Shared_Sram(for Ethos-U55, Ethos-U65, Ethos-85), Sram_Only(for Ethos-U55, Ethos-U65, Ethos-U85) or Dedicated_Sram(for Ethos-U65, Ethos-U85)."
    echo "                                  Default: Shared_Sram for the Ethos-U55 and Sram_Only for the Ethos-U85"
    echo "  --etdump                        Adds Devtools etdump support to track timing, etdump area will be base64 encoded in the log"
    echo "  --extra_build_flags=<FLAGS>     Extra flags to pass to cmake like -DET_ARM_BAREMETAL_METHOD_ALLOCATOR_POOL_SIZE=60000 Default: none "
    echo "  --output=<FOLDER>               Output folder Default: <MODEL>/<MODEL>_<TARGET INFO>.pte"
    echo "  --et_build_root=<FOLDER>        Build output root folder to use, defaults to ${et_build_root}"
    echo "  --ethosu_tools_dir=<FOLDER>     Path to your Ethos-U tools dir if you not using default: ${ethosu_tools_dir}"
    echo "  --flash                         Flash the generated elf file to the target"
    exit 0
}

for arg in "$@"; do
    case $arg in
      -h|--help) help ;;
      --pte=*) pte_file="${arg#*=}";;
      --target=*) target="${arg#*=}";;
      --build_type=*) build_type="${arg#*=}";;
      --bundleio) bundleio=true ;;
      --system_config=*) system_config="${arg#*=}";;
      --memory_mode=*) memory_mode="${arg#*=}";;
      --etdump) build_with_etdump=true ;;
      --extra_build_flags=*) extra_build_flags="${arg#*=}";;
      --output=*) output_folder="${arg#*=}" ; output_folder_set=true ;;
      --et_build_root=*) et_build_root="${arg#*=}";;
      --ethosu_tools_dir=*) ethosu_tools_dir="${arg#*=}";;
      --flash) flash=true ;;
      *)
      ;;
    esac
done

# Source the tools
# This should be prepared by the setup.sh
[[ -f ${setup_path_script} ]] \
    || { echo "Missing ${setup_path_script}. ${_setup_msg}"; exit 1; }

source ${setup_path_script}

pte_file=$(realpath ${pte_file})
ethosu_tools_dir=$(realpath ${ethosu_tools_dir})
ethos_u_root_dir="$ethosu_tools_dir/ethos-u"
mkdir -p "${ethos_u_root_dir}"
ethosu_tools_dir=$(realpath ${ethos_u_root_dir})

et_build_dir=${et_build_root}/cmake-out
et_build_dir=$(realpath ${et_build_dir})

if [ "$output_folder_set" = false ] ; then
    # remove file ending
    output_folder=${pte_file%.*}
fi

# Set target based variables
if [[ ${target} == "cortex-m33" ]]
then
    system_config="Cortex_M33_Config" 
    memory_mode="Cortex_M33_memory"
else
    if [[ ${system_config} == "" ]]
    then
        system_config="Ethos_U55_High_End_Embedded"
        if [[ ${target} =~ "ethos-u85" ]]
        then
            system_config="Ethos_U85_SYS_DRAM_Mid"
        fi
    fi

    if [[ ${memory_mode} == "" ]]
    then
        memory_mode="Shared_Sram"
        if [[ ${target} =~ "ethos-u85" ]]
        then
            memory_mode="Sram_Only"
        fi
    fi
fi

mkdir -p "${output_folder}"
output_folder=$(realpath ${output_folder})

if [[ ${target} == *"ethos-u55"*  ]]; then
    target_cpu=cortex-m55
elif [[ ${target} == *"ethos-u85"* ]]; then
    target_cpu=cortex-m85
elif [[ ${target} == "cortex-m33" ]]; then
    target_cpu=cortex-m33
else
    echo "Unsupported target: ${target}"
    exit 1
fi

echo "--------------------------------------------------------------------------------"
echo "Build Arm Baremetal executor_runner for ${target} with ${pte_file} using ${system_config} ${memory_mode} ${extra_build_flags} to '${output_folder}/cmake-out'"
echo "--------------------------------------------------------------------------------"

#Executor runner cmake path
cd ${et_root_dir}/examples/arm/executor_runner

if [ "$bundleio" = true ] ; then
    build_bundleio_flags=" -DET_BUNDLE_IO=ON "
fi

if [ "$build_with_etdump" = true ] ; then
    build_with_etdump_flags=" -DEXECUTORCH_ENABLE_EVENT_TRACER=ON "
fi

echo "Building with BundleIO/etdump/extra flags: ${build_bundleio_flags} ${build_with_etdump_flags} ${extra_build_flags}"

#TODO add the option to pass the cmake flags
cmake \
    -DCMAKE_BUILD_TYPE=${build_type}            \
    -DCMAKE_TOOLCHAIN_FILE=${toolchain_cmake}   \
    -DTARGET_CPU=${target_cpu}                  \
    -DET_DIR_PATH:PATH=${et_root_dir}           \
    -DET_BUILD_DIR_PATH:PATH=${et_build_dir}    \
    -DET_PTE_FILE_PATH:PATH="${pte_file}"       \
    -DETHOS_SDK_PATH:PATH=${ethos_u_root_dir}   \
    -DETHOSU_TARGET_NPU_CONFIG=${target}        \
    ${build_bundleio_flags}                     \
    ${build_with_etdump_flags}                  \
    -DPYTHON_EXECUTABLE=$(which python3)        \
    -DSYSTEM_CONFIG=${system_config}            \
    -DMEMORY_MODE=${memory_mode}                \
    ${extra_build_flags}                        \
    -B ${output_folder}/cmake-out

echo "[${BASH_SOURCE[0]}] Configured CMAKE"

cmake --build ${output_folder}/cmake-out -j$(nproc) -- arm_executor_runner

echo "[${BASH_SOURCE[0]}] Generated baremetal elf file:"
find ${output_folder}/cmake-out -name "arm_executor_runner.elf"
echo "executable_text: $(find ${output_folder}/cmake-out -name arm_executor_runner.elf -exec arm-none-eabi-size {} \; | grep -v filename | awk '{print $1}') bytes"
echo "executable_data: $(find ${output_folder}/cmake-out -name arm_executor_runner.elf -exec arm-none-eabi-size {} \; | grep -v filename | awk '{print $2}') bytes"
echo "executable_bss:  $(find ${output_folder}/cmake-out -name arm_executor_runner.elf -exec arm-none-eabi-size {} \; | grep -v filename | awk '{print $3}') bytes"

if [ "$flash" = true ] ; then
    echo "Flashing the generated elf file to the target"
    if [[ ${target} == "cortex-m33" ]]; then
        STM32_Programmer_CLI.exe -c port=SWD freq=4000 -e all #Erase Flash memory 

        # Use find to locate the .elf file in the build directory
        elf_file=$(find ${output_folder}/cmake-out -name "*.elf" -print -quit)

        # Check if an .elf file was found
        if [ -z "$elf_file" ]; then
        echo "No .elf file found in the build directory."
        exit 1
        fi

        # Convert the Linux path to a Windows path
        win_path=$(wslpath -m "$elf_file")

        STM32_Programmer_CLI.exe -c port=SWD freq=4000 -w "$win_path" 0x08000000
    else
        echo "Unsupported target: ${target}"
        exit 1
    fi
fi