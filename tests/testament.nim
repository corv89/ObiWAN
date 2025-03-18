## Testament configuration for ObiWAN tests
##
## This module configures the common environment for all tests.

import os

# Get the project root directory
const ProjectDir = currentSourcePath().parentDir().parentDir()

# Add the main source directory to the module search path
const SrcDir = ProjectDir / "src"
putEnv("NIM_PATH", SrcDir)