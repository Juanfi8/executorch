# Enable CMake support for ASM and C languages
enable_language(C ASM)

# Add STM32CubeMX generated sources
add_subdirectory(cmake/stm32cubemx)

# Add linked libraries
target_link_libraries(arm_executor_runner
    stm32cubemx
)
