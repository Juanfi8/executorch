set(CMAKE_SYSTEM_NAME               Generic)

set(CMAKE_C_COMPILER_FORCED TRUE)
set(CMAKE_CXX_COMPILER_FORCED TRUE)
set(CMAKE_C_COMPILER_ID GNU)
set(CMAKE_CXX_COMPILER_ID GNU)

# Select C/C++ version
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Some default GCC settings
# arm-none-eabi- must be part of path environment
set(TOOLCHAIN_PREFIX                arm-none-eabi-)

set(CMAKE_C_COMPILER                ${TOOLCHAIN_PREFIX}gcc)
set(CMAKE_ASM_COMPILER              ${CMAKE_C_COMPILER})
set(CMAKE_CXX_COMPILER              ${TOOLCHAIN_PREFIX}g++)
set(CMAKE_LINKER                    ${TOOLCHAIN_PREFIX}ld)
set(CMAKE_OBJCOPY                   ${TOOLCHAIN_PREFIX}objcopy)
set(CMAKE_SIZE                      ${TOOLCHAIN_PREFIX}size)

set(CMAKE_EXECUTABLE_SUFFIX_ASM     ".elf")
set(CMAKE_EXECUTABLE_SUFFIX_C       ".elf")
set(CMAKE_EXECUTABLE_SUFFIX_CXX     ".elf")

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# Set the target cpu from the command line
set(TARGET_CPU
    "cortex-m33" #Default target 
    CACHE STRING "Target CPU"
)
string(TOLOWER ${TARGET_CPU} CMAKE_SYSTEM_PROCESSOR)


set(GCC_CPU ${CMAKE_SYSTEM_PROCESSOR})
#Replace cortex-m85 with cortex-m55?
string(REPLACE "cortex-m85" "cortex-m55" GCC_CPU ${GCC_CPU}) 

set (TARGET_FLAGS "-mcpu=${GCC_CPU} -mthumb") #Base target 

#TODO Set floating point unit - check m33
if(CMAKE_SYSTEM_PROCESSOR MATCHES "\\+fp")
    set(FLOAT hard)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "\\+nofp")
    set(FLOAT soft)
elseif(
    CMAKE_SYSTEM_PROCESSOR MATCHES "cortex-m55(\\+|$)"
    OR CMAKE_SYSTEM_PROCESSOR MATCHES "cortex-m85(\\+|$)"
)
    set(FLOAT hard)
elseif(  CMAKE_SYSTEM_PROCESSOR MATCHES "cortex-m33(\\+|$)" #Modified
        OR CMAKE_SYSTEM_PROCESSOR MATCHES "cortex-m4(\\+|$)"
            OR CMAKE_SYSTEM_PROCESSOR MATCHES "cortex-m7(\\+|$)")
    set(FLOAT hard)
    set(FPU_CONFIG "fpv4-sp-d16")
    set(TARGET_FLAGS "${TARGET_FLAGS} -mfpu=${FPU_CONFIG}")
else()
    set(FLOAT soft)
endif()
if(FLOAT)
    set(TARGET_FLAGS "${TARGET_FLAGS} -mfloat-abi=${FLOAT}")
endif()

#Transform the target flags into a list

separate_arguments(TARGET_FLAGS_LIST UNIX_COMMAND "${TARGET_FLAGS}")

#Compile options
add_compile_options(
    ${TARGET_FLAGS_LIST}
    # "$<$<CONFIG:DEBUG>:-gdwarf-3>" #Debugging info
    "$<$<COMPILE_LANGUAGE:CXX>:-fno-unwind-tables;-fno-rtti;-fno-exceptions>" #-fno-threadsafe-statics in STM cmake
    -fdata-sections
    -ffunction-sections
)

# add_compile_options(-Wall -Wextra -Wpedantic -Wno-psabi) #Warning flags
add_compile_options(-Wno-psabi) #Warning flags

#Compile defines
add_compile_definitions("$<$<NOT:$<CONFIG:DEBUG>>:NDEBUG>")

#Link options
add_link_options(
    ${TARGET_FLAGS_LIST}
    -Wl,--gc-sections #Remove unused sections (garbage collection)
    -Wl,--nmagic 
)

if(SEMIHOSTING)
    add_link_options(--specs=rdimon.specs)
else()
    if(CMAKE_SYSTEM_PROCESSOR STREQUAL "cortex-m33")
        add_link_options(
            --specs=nano.specs # Use newlib-nano
            -u _printf_float # Enable printf float support
        )
        # Add linker script
        set(LINKER_SCRIPT "${CMAKE_SOURCE_DIR}/STM32H563xx_FLASH.ld")
        add_link_options(-T${LINKER_SCRIPT})
        # Add memory usage output
        add_link_options(-Wl,--print-memory-usage)
        # Generate map file
        add_link_options(-Wl,-Map=${CMAKE_PROJECT_NAME}.map)
        # Standard libraries
        add_link_options(-Wl,--start-group -lc -lm -Wl,--end-group)
        # C++ standard libraries (conditionally)
        add_link_options(
            "$<$<COMPILE_LANGUAGE:CXX>:-Wl,--start-group;-lstdc++;-lsupc++;-Wl,--end-group>"
        )
    else()
        add_link_options(--specs=nosys.specs)
    endif()
endif()

#Assembly options
set(CMAKE_ASM_FLAGS "${TARGET_FLAGS} -x assembler-with-cpp -MMD -MP")

#Print information to console
message(STATUS "Configuring for ARM cross-compilation")
message(STATUS "Target flags: ${TARGET_FLAGS}")

# #Optimization and debugging
# if(CMAKE_BUILD_TYPE MATCHES Debug)
#     set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O0 -g3")
# endif()
# if(CMAKE_BUILD_TYPE MATCHES Release)
#     set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Os -g0")
# endif()