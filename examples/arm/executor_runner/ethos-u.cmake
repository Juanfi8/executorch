set(ETHOS_SDK_PATH
    "${ET_DIR_PATH}/examples/arm/ethos-u-scratch/ethos-u"
    CACHE PATH "Path to Ethos-U bare metal driver/env"
)
if(FETCH_ETHOS_U_CONTENT)
  # Download ethos_u dependency if needed.
  file(MAKE_DIRECTORY ${ETHOS_SDK_PATH}/../ethos_u)

  #TODO
  include(FetchContent)
  set(ethos_u_base_rev "25.02")
  FetchContent_Declare(
    ethos_u
    GIT_REPOSITORY https://git.gitlab.arm.com/artificial-intelligence/ethos-u/ethos-u.git
    GIT_TAG ${ethos_u_base_rev}
    SOURCE_DIR ${ETHOS_SDK_PATH}
    BINARY_DIR ${ETHOS_SDK_PATH}
    SUBBUILD_DIR ${ETHOS_SDK_PATH}/../ethos_u-subbuild
    SOURCE_SUBDIR none
  )

  FetchContent_MakeAvailable(ethos_u)

  # Get ethos_u externals only if core_platform folder does not already exist.
  if(NOT EXISTS "${ETHOS_SDK_PATH}/core_platform")
    execute_process(COMMAND ${PYTHON_EXECUTABLE} fetch_externals.py -c ${ethos_u_base_rev}.json fetch
                    WORKING_DIRECTORY ${ETHOS_SDK_PATH}
                    COMMAND_ECHO STDOUT
    )
  endif()

  # Always patch the core_platform repo since this is fast enough.
  set(core_platform_base_rev "b728c774158248ba2cad8e78a515809e1eb9b77f")
  set(patch_dir "${ET_DIR_PATH}/examples/arm/ethos-u-setup")
  execute_process(COMMAND bash -c "pwd && source backends/arm/scripts/utils.sh && patch_repo ${ETHOS_SDK_PATH}/core_platform ${core_platform_base_rev} ${patch_dir}"
    WORKING_DIRECTORY ${ET_DIR_PATH}
    COMMAND_ECHO STDOUT
  )
endif()

# Selects timing adapter values matching system_config.
# Default is Ethos_U55_High_End_Embedded, simulating optimal hardware for the Corestone-300.
set(SYSTEM_CONFIG "Ethos_U55_High_End_Embedded" CACHE STRING "System config")
set(MEMORY_MODE "Shared_Sram" CACHE STRING "Vela memory mode")

message(STATUS "SYSTEM_CONFIG is ${SYSTEM_CONFIG}")
message(STATUS "MEMORY_MODE is ${MEMORY_MODE}")

get_filename_component(ETHOS_SDK_PATH ${ETHOS_SDK_PATH} REALPATH)

# Dependencies from the Ethos-U Core This is the platform target of
# Corstone-300, that includes ethosu_core_driver and bare-metal bringup
# libraries. We link against ethosu_target_init which includes all of these
# dependencies.
if(SYSTEM_CONFIG STREQUAL "Ethos_U55_High_End_Embedded")
  add_subdirectory(${ETHOS_SDK_PATH}/core_platform/targets/corstone-300 target)
  set(TARGET_BOARD "corstone-300")
  if(MEMORY_MODE STREQUAL "Shared_Sram")
    target_compile_definitions(ethosu_target_common INTERFACE
        # ETHOSU_MODEL=0 place pte file/data in SRAM area
        # ETHOSU_MODEL=1 place pte file/data in DDR area
        ETHOSU_MODEL=1
        # Configure NPU architecture timing adapters
        # This is just example numbers and you should make this match your hardware
        # SRAM
        ETHOSU_TA_MAXR_0=8
        ETHOSU_TA_MAXW_0=8
        ETHOSU_TA_MAXRW_0=0
        ETHOSU_TA_RLATENCY_0=32
        ETHOSU_TA_WLATENCY_0=32
        ETHOSU_TA_PULSE_ON_0=3999
        ETHOSU_TA_PULSE_OFF_0=1
        ETHOSU_TA_BWCAP_0=4000
        ETHOSU_TA_PERFCTRL_0=0
        ETHOSU_TA_PERFCNT_0=0
        ETHOSU_TA_MODE_0=1
        ETHOSU_TA_HISTBIN_0=0
        ETHOSU_TA_HISTCNT_0=0
        # Flash
        ETHOSU_TA_MAXR_1=2
        ETHOSU_TA_MAXW_1=0
        ETHOSU_TA_MAXRW_1=0
        ETHOSU_TA_RLATENCY_1=64
        ETHOSU_TA_WLATENCY_1=0
        ETHOSU_TA_PULSE_ON_1=320
        ETHOSU_TA_PULSE_OFF_1=80
        ETHOSU_TA_BWCAP_1=50
        ETHOSU_TA_PERFCTRL_1=0
        ETHOSU_TA_PERFCNT_1=0
        ETHOSU_TA_MODE_1=1
        ETHOSU_TA_HISTBIN_1=0
        ETHOSU_TA_HISTCNT_1=0
        )
  elseif(MEMORY_MODE STREQUAL "Sram_Only")
    target_compile_definitions(ethosu_target_common INTERFACE
      # This is just example numbers and you should make this match your hardware
      # SRAM
      ETHOSU_TA_MAXR_0=8
      ETHOSU_TA_MAXW_0=8
      ETHOSU_TA_MAXRW_0=0
      ETHOSU_TA_RLATENCY_0=32
      ETHOSU_TA_WLATENCY_0=32
      ETHOSU_TA_PULSE_ON_0=3999
      ETHOSU_TA_PULSE_OFF_0=1
      ETHOSU_TA_BWCAP_0=4000
      ETHOSU_TA_PERFCTRL_0=0
      ETHOSU_TA_PERFCNT_0=0
      ETHOSU_TA_MODE_0=1
      ETHOSU_TA_HISTBIN_0=0
      ETHOSU_TA_HISTCNT_0=0
      # Set the second Timing Adapter to SRAM latency & bandwidth
      ETHOSU_TA_MAXR_1=8
      ETHOSU_TA_MAXW_1=8
      ETHOSU_TA_MAXRW_1=0
      ETHOSU_TA_RLATENCY_1=32
      ETHOSU_TA_WLATENCY_1=32
      ETHOSU_TA_PULSE_ON_1=3999
      ETHOSU_TA_PULSE_OFF_1=1
      ETHOSU_TA_BWCAP_1=4000
      ETHOSU_TA_PERFCTRL_1=0
      ETHOSU_TA_PERFCNT_1=0
      ETHOSU_TA_MODE_1=1
      ETHOSU_TA_HISTBIN_1=0
      ETHOSU_TA_HISTCNT_1=0
      )

  else()
    message(FATAL_ERROR "Unsupported memory_mode ${MEMORY_MODE} for the Ethos-U55. The Ethos-U55 supports only Shared_Sram and Sram_Only.")
  endif()
elseif(SYSTEM_CONFIG STREQUAL "Ethos_U55_Deep_Embedded")
  add_subdirectory(${ETHOS_SDK_PATH}/core_platform/targets/corstone-300 target)
  set(TARGET_BOARD "corstone-300")
  if(MEMORY_MODE STREQUAL "Shared_Sram")
    target_compile_definitions(ethosu_target_common INTERFACE
        # ETHOSU_MODEL=0 place pte file/data in SRAM area
        # ETHOSU_MODEL=1 place pte file/data in DDR area
        ETHOSU_MODEL=1
        # Configure NPU architecture timing adapters
        # This is just example numbers and you should make this match your hardware
        # SRAM
        ETHOSU_TA_MAXR_0=4
        ETHOSU_TA_MAXW_0=4
        ETHOSU_TA_MAXRW_0=0
        ETHOSU_TA_RLATENCY_0=8
        ETHOSU_TA_WLATENCY_0=8
        ETHOSU_TA_PULSE_ON_0=3999
        ETHOSU_TA_PULSE_OFF_0=1
        ETHOSU_TA_BWCAP_0=4000
        ETHOSU_TA_PERFCTRL_0=0
        ETHOSU_TA_PERFCNT_0=0
        ETHOSU_TA_MODE_0=1
        ETHOSU_TA_HISTBIN_0=0
        ETHOSU_TA_HISTCNT_0=0
        # Flash
        ETHOSU_TA_MAXR_1=2
        ETHOSU_TA_MAXW_1=0
        ETHOSU_TA_MAXRW_1=0
        ETHOSU_TA_RLATENCY_1=32
        ETHOSU_TA_WLATENCY_1=0
        ETHOSU_TA_PULSE_ON_1=360
        ETHOSU_TA_PULSE_OFF_1=40
        ETHOSU_TA_BWCAP_1=25
        ETHOSU_TA_PERFCTRL_1=0
        ETHOSU_TA_PERFCNT_1=0
        ETHOSU_TA_MODE_1=1
        ETHOSU_TA_HISTBIN_1=0
        ETHOSU_TA_HISTCNT_1=0
        )
    elseif(MEMORY_MODE STREQUAL "Sram_Only")
      target_compile_definitions(ethosu_target_common INTERFACE
      # Configure NPU architecture timing adapters
      # This is just example numbers and you should make this match your hardware
      # SRAM
      ETHOSU_TA_MAXR_0=4
      ETHOSU_TA_MAXW_0=4
      ETHOSU_TA_MAXRW_0=0
      ETHOSU_TA_RLATENCY_0=8
      ETHOSU_TA_WLATENCY_0=8
      ETHOSU_TA_PULSE_ON_0=3999
      ETHOSU_TA_PULSE_OFF_0=1
      ETHOSU_TA_BWCAP_0=4000
      ETHOSU_TA_PERFCTRL_0=0
      ETHOSU_TA_PERFCNT_0=0
      ETHOSU_TA_MODE_0=1
      ETHOSU_TA_HISTBIN_0=0
      ETHOSU_TA_HISTCNT_0=0
      # Set the second Timing Adapter to SRAM latency & bandwidth
      ETHOSU_TA_MAXR_1=4
      ETHOSU_TA_MAXW_1=4
      ETHOSU_TA_MAXRW_1=0
      ETHOSU_TA_RLATENCY_1=8
      ETHOSU_TA_WLATENCY_1=8
      ETHOSU_TA_PULSE_ON_1=3999
      ETHOSU_TA_PULSE_OFF_1=1
      ETHOSU_TA_BWCAP_1=4000
      ETHOSU_TA_PERFCTRL_1=0
      ETHOSU_TA_PERFCNT_1=0
      ETHOSU_TA_MODE_1=1
      ETHOSU_TA_HISTBIN_1=0
      ETHOSU_TA_HISTCNT_1=0
      )
    else()
      message(FATAL_ERROR "Unsupported memory_mode ${MEMORY_MODE} for the Ethos-U55. The Ethos-U55 supports only Shared_Sram and Sram_Only.")
  endif()
elseif(SYSTEM_CONFIG STREQUAL "Ethos_U85_SYS_DRAM_Low")
  add_subdirectory(${ETHOS_SDK_PATH}/core_platform/targets/corstone-320 target)
  set(TARGET_BOARD "corstone-320")
  if(MEMORY_MODE STREQUAL "Dedicated_Sram")
    target_compile_definitions(ethosu_target_common INTERFACE
        # ETHOSU_MODEL=0 place pte file/data in SRAM area
        # ETHOSU_MODEL=1 place pte file/data in DDR area
        ETHOSU_MODEL=1
        # Configure NPU architecture timing adapters
        # This is just example numbers and you should make this match your hardware
        # SRAM
        ETHOSU_TA_MAXR_0=8
        ETHOSU_TA_MAXW_0=8
        ETHOSU_TA_MAXRW_0=0
        ETHOSU_TA_RLATENCY_0=16
        ETHOSU_TA_WLATENCY_0=16
        ETHOSU_TA_PULSE_ON_0=3999
        ETHOSU_TA_PULSE_OFF_0=1
        ETHOSU_TA_BWCAP_0=4000
        ETHOSU_TA_PERFCTRL_0=0
        ETHOSU_TA_PERFCNT_0=0
        ETHOSU_TA_MODE_0=1
        ETHOSU_TA_HISTBIN_0=0
        ETHOSU_TA_HISTCNT_0=0
        # DRAM
        ETHOSU_TA_MAXR_1=24
        ETHOSU_TA_MAXW_1=12
        ETHOSU_TA_MAXRW_1=0
        ETHOSU_TA_RLATENCY_1=250
        ETHOSU_TA_WLATENCY_1=125
        ETHOSU_TA_PULSE_ON_1=4000
        ETHOSU_TA_PULSE_OFF_1=1000
        ETHOSU_TA_BWCAP_1=2344
        ETHOSU_TA_PERFCTRL_1=0
        ETHOSU_TA_PERFCNT_1=0
        ETHOSU_TA_MODE_1=1
        ETHOSU_TA_HISTBIN_1=0
        ETHOSU_TA_HISTCNT_1=0
        )
  elseif(MEMORY_MODE STREQUAL "Sram_Only")
      target_compile_definitions(ethosu_target_common INTERFACE
      # ETHOSU_MODEL=0 place pte file/data in SRAM area
      # ETHOSU_MODEL=1 place pte file/data in DDR area
      ETHOSU_MODEL=1
      # Configure NPU architecture timing adapters
      # This is just example numbers and you should make this match your hardware
      # SRAM
      ETHOSU_TA_MAXR_0=8
      ETHOSU_TA_MAXW_0=8
      ETHOSU_TA_MAXRW_0=0
      ETHOSU_TA_RLATENCY_0=16
      ETHOSU_TA_WLATENCY_0=16
      ETHOSU_TA_PULSE_ON_0=3999
      ETHOSU_TA_PULSE_OFF_0=1
      ETHOSU_TA_BWCAP_0=4000
      ETHOSU_TA_PERFCTRL_0=0
      ETHOSU_TA_PERFCNT_0=0
      ETHOSU_TA_MODE_0=1
      ETHOSU_TA_HISTBIN_0=0
      ETHOSU_TA_HISTCNT_0=0
      # Set the second Timing Adapter to SRAM latency & bandwidth
      ETHOSU_TA_MAXR_1=8
      ETHOSU_TA_MAXW_1=8
      ETHOSU_TA_MAXRW_1=0
      ETHOSU_TA_RLATENCY_1=16
      ETHOSU_TA_WLATENCY_1=16
      ETHOSU_TA_PULSE_ON_1=3999
      ETHOSU_TA_PULSE_OFF_1=1
      ETHOSU_TA_BWCAP_1=4000
      ETHOSU_TA_PERFCTRL_1=0
      ETHOSU_TA_PERFCNT_1=0
      ETHOSU_TA_MODE_1=1
      ETHOSU_TA_HISTBIN_1=0
      ETHOSU_TA_HISTCNT_1=0
      )
  endif()
elseif(SYSTEM_CONFIG STREQUAL "Ethos_U85_SYS_DRAM_Mid" OR SYSTEM_CONFIG STREQUAL "Ethos_U85_SYS_DRAM_High")
  add_subdirectory(${ETHOS_SDK_PATH}/core_platform/targets/corstone-320 target)
  set(TARGET_BOARD "corstone-320")
  if(MEMORY_MODE STREQUAL "Dedicated_Sram")
    target_compile_definitions(ethosu_target_common INTERFACE
        # ETHOSU_MODEL=0 place pte file/data in SRAM area
        # ETHOSU_MODEL=1 place pte file/data in DDR area
        ETHOSU_MODEL=1
        # Configure NPU architecture timing adapters
        # This is just example numbers and you should make this match your hardware
        # SRAM
        ETHOSU_TA_MAXR_0=8
        ETHOSU_TA_MAXW_0=8
        ETHOSU_TA_MAXRW_0=0
        ETHOSU_TA_RLATENCY_0=32
        ETHOSU_TA_WLATENCY_0=32
        ETHOSU_TA_PULSE_ON_0=3999
        ETHOSU_TA_PULSE_OFF_0=1
        ETHOSU_TA_BWCAP_0=4000
        ETHOSU_TA_PERFCTRL_0=0
        ETHOSU_TA_PERFCNT_0=0
        ETHOSU_TA_MODE_0=1
        ETHOSU_TA_HISTBIN_0=0
        ETHOSU_TA_HISTCNT_0=0
        # DRAM
        ETHOSU_TA_MAXR_1=64
        ETHOSU_TA_MAXW_1=32
        ETHOSU_TA_MAXRW_1=0
        ETHOSU_TA_RLATENCY_1=500
        ETHOSU_TA_WLATENCY_1=250
        ETHOSU_TA_PULSE_ON_1=4000
        ETHOSU_TA_PULSE_OFF_1=1000
        ETHOSU_TA_BWCAP_1=3750
        ETHOSU_TA_PERFCTRL_1=0
        ETHOSU_TA_PERFCNT_1=0
        ETHOSU_TA_MODE_1=1
        ETHOSU_TA_HISTBIN_1=0
        ETHOSU_TA_HISTCNT_1=0
        )
  elseif(MEMORY_MODE STREQUAL "Sram_Only")
    target_compile_definitions(ethosu_target_common INTERFACE
    # ETHOSU_MODEL=0 place pte file/data in SRAM area
    # ETHOSU_MODEL=1 place pte file/data in DDR area
    ETHOSU_MODEL=1
    # Configure NPU architecture timing adapters
    # This is just example numbers and you should make this match your hardware
    # SRAM
    ETHOSU_TA_MAXR_0=8
    ETHOSU_TA_MAXW_0=8
    ETHOSU_TA_MAXRW_0=0
    ETHOSU_TA_RLATENCY_0=32
    ETHOSU_TA_WLATENCY_0=32
    ETHOSU_TA_PULSE_ON_0=3999
    ETHOSU_TA_PULSE_OFF_0=1
    ETHOSU_TA_BWCAP_0=4000
    ETHOSU_TA_PERFCTRL_0=0
    ETHOSU_TA_PERFCNT_0=0
    ETHOSU_TA_MODE_0=1
    ETHOSU_TA_HISTBIN_0=0
    ETHOSU_TA_HISTCNT_0=0
    # Set the second Timing Adapter to SRAM latency & bandwidth
    ETHOSU_TA_MAXR_1=8
    ETHOSU_TA_MAXW_1=8
    ETHOSU_TA_MAXRW_1=0
    ETHOSU_TA_RLATENCY_1=32
    ETHOSU_TA_WLATENCY_1=32
    ETHOSU_TA_PULSE_ON_1=3999
    ETHOSU_TA_PULSE_OFF_1=1
    ETHOSU_TA_BWCAP_1=4000
    ETHOSU_TA_PERFCTRL_1=0
    ETHOSU_TA_PERFCNT_1=0
    ETHOSU_TA_MODE_1=1
    ETHOSU_TA_HISTBIN_1=0
    ETHOSU_TA_HISTCNT_1=0
    )
  endif()
else()
  message(FATAL_ERROR "Unsupported SYSTEM_CONFIG: ${SYSTEM_CONFIG}")
endif()

#Delegate library
add_library(executorch_delegate_ethos_u STATIC IMPORTED)
set_property(
  TARGET executorch_delegate_ethos_u
  PROPERTY IMPORTED_LOCATION "${ET_BUILD_DIR_PATH}/backends/arm/libexecutorch_delegate_ethos_u.a"
)

# Include the target's bare-metal linker script
ethosu_eval_link_options(arm_executor_runner) #Function defined in ./ethos-u-scratch/ethos-u/core_platform/cmake/helpers.cmake

target_link_libraries(arm_executor_runner ethosu_target_init)
