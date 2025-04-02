# Copyright 2023-2025 Arm Limited and/or its affiliates.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

cmake_minimum_required(VERSION 3.22)
# Setup compiler settings
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)


# Set the project name
project(arm_executor_runner C CXX ASM)

option(SEMIHOSTING "Enable semihosting" OFF)
option(ET_ARM_BAREMETAL_METHOD_ALLOCATOR_POOL_SIZE "Set ET_ARM_BAREMETAL_METHOD_ALLOCATOR_POOL_SIZE to specify memory alloction pool size" OFF)
option(ET_ARM_BAREMETAL_TEMP_ALLOCATOR_POOL_SIZE "Set ET_ARM_BAREMETAL_TEMP_ALLOCATOR_POOL_SIZE to specify temp alloction pool size" OFF)
option(ET_BUNDLE_IO "Set to compile in BundleIO support" OFF)
option(ET_ATOL "Set atol to use for BundleIO testing" OFF)
option(ET_RTOL "Set rtol to use for BundleIO testing" OFF)
option(DUMP_INPUT "Set to dump input data" OFF)

if(NOT DEFINED ET_PTE_FILE_PATH AND NOT ${SEMIHOSTING})
  message(
    FATAL_ERROR
      "ET_PTE_FILE_PATH must specify a model .pte or .bpte, for bare metal systems the "
      "model is built into the binary."
  )
endif()

# Example ExecuTorch demo for bare metal Cortex-M based systems
set(ET_DIR_PATH
    "../../.."
    CACHE PATH "Path to ExecuTorch dir"
)
set(ET_BUILD_DIR_PATH
    "${ET_DIR_PATH}/cmake-out"
    CACHE PATH "Path to ExecuTorch build dir"
)
set(ET_INCLUDE_PATH
    "${ET_DIR_PATH}/.."
    CACHE PATH "Path to ExecuTorch headers"
)
set(ET_PTE_FILE_PATH
    ""
    CACHE PATH "Path to ExecuTorch model pte"
)
set(PYTHON_EXECUTABLE
    "python"
    CACHE PATH "Define to override python executable used"
)

if(NOT ${SEMIHOSTING})
  get_filename_component(ET_PTE_FILE_PATH ${ET_PTE_FILE_PATH} REALPATH)
endif()

get_filename_component(ET_BUILD_DIR_PATH ${ET_BUILD_DIR_PATH} REALPATH)
get_filename_component(ET_DIR_PATH ${ET_DIR_PATH} REALPATH)
get_filename_component(ET_INCLUDE_PATH ${ET_INCLUDE_PATH} REALPATH)

#Required libraries

#ExecuTorch core
add_library(executorch STATIC IMPORTED)
set_property(
  TARGET executorch PROPERTY IMPORTED_LOCATION "${ET_BUILD_DIR_PATH}/libexecutorch.a"
)
add_library(executorch_core STATIC IMPORTED)
set_property(
  TARGET executorch_core
  PROPERTY IMPORTED_LOCATION "${ET_BUILD_DIR_PATH}/libexecutorch_core.a"
)
target_link_libraries(executorch INTERFACE executorch_core)

#Executorch portable operators 
add_library(portable_ops_lib STATIC IMPORTED)
set_property(
  TARGET portable_ops_lib
  PROPERTY IMPORTED_LOCATION "${ET_BUILD_DIR_PATH}/examples/arm/libarm_portable_ops_lib.a"
)
add_library(portable_kernels STATIC IMPORTED)
set_property(
  TARGET portable_kernels
  PROPERTY IMPORTED_LOCATION "${ET_BUILD_DIR_PATH}/kernels/portable/libportable_kernels.a"
)
add_library(extension_runner_util STATIC IMPORTED)
set_property(
  TARGET extension_runner_util
  PROPERTY
    IMPORTED_LOCATION "${ET_BUILD_DIR_PATH}/extension/runner_util/libextension_runner_util.a"

#Quantized operators
)
add_library(quantized_ops_lib STATIC IMPORTED)
set_property(
  TARGET quantized_ops_lib
  PROPERTY IMPORTED_LOCATION "${ET_BUILD_DIR_PATH}/kernels/quantized/libquantized_ops_lib.a"
)
add_library(quantized_kernels STATIC IMPORTED)
set_property(
  TARGET quantized_kernels
  PROPERTY IMPORTED_LOCATION "${ET_BUILD_DIR_PATH}/kernels/quantized/libquantized_kernels.a"
)

# Convert pte to header
if(NOT ${SEMIHOSTING})
  add_custom_target(
    gen_model_header DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/model_pte.h
  )

  add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/model_pte.h
    COMMAND ${PYTHON_EXECUTABLE} ${CMAKE_SOURCE_DIR}/pte_to_header.py --pte
            ${ET_PTE_FILE_PATH} --outdir ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${ET_PTE_FILE_PATH}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  )
endif()

# The arm_executor_runner executable
add_executable(arm_executor_runner)


# ET headers and generated headers includes
target_include_directories(
  arm_executor_runner PRIVATE ${ET_INCLUDE_PATH} ${ET_DIR_PATH}/runtime/core/portable_type/c10 ${CMAKE_CURRENT_BINARY_DIR}
)

target_compile_definitions(arm_executor_runner PRIVATE C10_USING_CUSTOM_GENERATED_MACROS)

# Need whole-archive to ensure C++ construtor's are called - this may be wasteful for
# bin size as we link in a number of other symbols. 
#TODO verify that other libs are not necessary
set(arm_executor_runner_link)
list(APPEND arm_executor_runner_link
  extension_runner_util
  executorch
  "-Wl,--whole-archive"
  portable_ops_lib
  portable_kernels
  "-Wl,--no-whole-archive"
  -Xlinker -Map=arm_executor_runner.map
)
# "-Wl,--whole-archive"
# executorch_delegate_ethos_u
# quantized_ops_lib
# portable_ops_lib
# quantized_kernels
# portable_kernels
# "-Wl,--no-whole-archive"
target_link_libraries(
  arm_executor_runner
  ${arm_executor_runner_link}
)

# Platform specific includes
if(CMAKE_SYSTEM_PROCESSOR MATCHES "cortex-m55(\\+|$)" 
OR CMAKE_SYSTEM_PROCESSOR MATCHES "cortex-m85(\\+|$)")
  add_subdirectory(ethos-u)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "cortex-m33(\\+|$)")
  add_subdirectory(stm32h5)
else()
  message(
    FATAL_ERROR
      "CMakeLists.txt: Unsupported target processor ${CMAKE_SYSTEM_PROCESSOR}"
  )
endif()

#Bundle IO and event tracer
if(EXECUTORCH_ENABLE_EVENT_TRACER)
  target_compile_options(arm_executor_runner PUBLIC -DET_EVENT_TRACER_ENABLED)

  add_library(etdump STATIC IMPORTED)
  set_property(
      TARGET etdump
      PROPERTY IMPORTED_LOCATION
           "${ET_BUILD_DIR_PATH}/lib/libetdump.a"
  )

  if(CMAKE_BUILD_TYPE MATCHES "Debug")
    set(FLATCCRT_LIB flatccrt_d)
  else()
    set(FLATCCRT_LIB flatccrt)
  endif()

  add_library(${FLATCCRT_LIB} STATIC IMPORTED)
  set_property(
      TARGET ${FLATCCRT_LIB}
      PROPERTY IMPORTED_LOCATION
           "${ET_BUILD_DIR_PATH}/lib/lib${FLATCCRT_LIB}.a"
  )

  list(APPEND arm_executor_runner_link
    etdump
    ${FLATCCRT_LIB}
  )
endif()

if(ET_BUNDLE_IO)
  add_library(bundled_program STATIC IMPORTED)
  set_property(
    TARGET bundled_program
    PROPERTY IMPORTED_LOCATION
        "${ET_BUILD_DIR_PATH}/lib/libbundled_program.a"
  )
  list(APPEND arm_executor_runner_link
    bundled_program
  )
endif()


#Compile definitions based on targets 

if(SEMIHOSTING)
  target_compile_definitions(arm_executor_runner PUBLIC SEMIHOSTING)
else()
  add_dependencies(arm_executor_runner gen_model_header)
endif()

if(ET_ARM_BAREMETAL_METHOD_ALLOCATOR_POOL_SIZE)
  target_compile_definitions(arm_executor_runner PUBLIC ET_ARM_BAREMETAL_METHOD_ALLOCATOR_POOL_SIZE=${ET_ARM_BAREMETAL_METHOD_ALLOCATOR_POOL_SIZE})
endif()

if(ET_ARM_BAREMETAL_TEMP_ALLOCATOR_POOL_SIZE)
  target_compile_definitions(arm_executor_runner PUBLIC ET_ARM_BAREMETAL_TEMP_ALLOCATOR_POOL_SIZE=${ET_ARM_BAREMETAL_TEMP_ALLOCATOR_POOL_SIZE})
endif()

if(ET_BUNDLE_IO)
  target_compile_definitions(arm_executor_runner PUBLIC -DET_BUNDLE_IO)
endif()

if(ET_ATOL)
  target_compile_definitions(arm_executor_runner PUBLIC ET_ATOL=${ET_ATOL})
endif()

if(ET_RTOL)
  target_compile_definitions(arm_executor_runner PUBLIC ET_RTOL=${ET_RTOL})
endif()

if(DUMP_INPUT)
  target_compile_definitions(arm_executor_runner PUBLIC -DDUMP_INPUT) # To print runner inputs
endif()

# Fixup compilation of retarget.c
if(SEMIHOSTING)
  # Remove this when MLBEDSW-8910 is closed.
  set_source_files_properties(
    ${ETHOS_SDK_PATH}/core_platform/targets/${TARGET_BOARD}/retarget.c
    PROPERTIES HEADER_FILE_ONLY TRUE
  )
endif()