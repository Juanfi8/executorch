# Enable CMake support for ASM and C languages
enable_language(C ASM)

# Set the source files
set(SOURCES
    Src/main.c
    Src/arm_executor_runner.cpp
    Src/arm_perf_monitor.cpp
    # Add other source files here
)

# Create an executable object type
target_sources(arm_executor_runner PRIVATE ${SOURCES})

# Add STM32CubeMX generated sources
add_subdirectory(cmake/stm32cubemx)


target_link_libraries(arm_executor_runner
    stm32cubemx
)
