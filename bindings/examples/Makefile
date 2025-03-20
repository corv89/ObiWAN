# Makefile for ObiWAN C examples

# Compiler settings
CC = gcc
CFLAGS = -Wall -Wextra -Werror -pedantic -std=c99

# Directory paths
PROJECT_ROOT = ../..
BUILD_DIR = $(PROJECT_ROOT)/build
BIN_DIR = $(BUILD_DIR)
EXAMPLES_DIR = $(BUILD_DIR)/examples
INCLUDE_DIR = ../generated

# Create examples directory if needed
$(shell mkdir -p $(EXAMPLES_DIR))

# Library paths
LIB_NAME = obiwan
LIB_PATH = $(BUILD_DIR)/lib$(LIB_NAME).so

# Example targets
EXAMPLES = c_example c_example_dlopen
TARGETS = $(addprefix $(BIN_DIR)/,$(EXAMPLES))

# Default target
all: $(TARGETS)

# Standard example using static linking
$(BIN_DIR)/c_example: c_example.c
	$(CC) $(CFLAGS) -I$(INCLUDE_DIR) -L$(BUILD_DIR) -l$(LIB_NAME) $< -o $@

# Example using dynamic loading (dlopen)
# Note: We disable -pedantic and -Werror for this example because dlsym requires casting from void* to function pointers
$(BIN_DIR)/c_example_dlopen: c_example_dlopen.c
	$(CC) -Wall -Wextra -std=c99 $< -o $@ -ldl

# Clean target
clean:
	rm -f $(BIN_DIR)/c_example $(BIN_DIR)/c_example_dlopen

# Make sure library is built
library:
	@echo "Building ObiWAN shared library..."
	@cd $(PROJECT_ROOT) && nimble bindings

# Run examples (builds the examples first)
run: all
	@echo "Running normal C example..."
	@cd $(PROJECT_ROOT) && LD_LIBRARY_PATH=./build DYLD_LIBRARY_PATH=./build ./build/c_example
	@echo "\nRunning dlopen C example..."
	@cd $(PROJECT_ROOT) && LD_LIBRARY_PATH=./build DYLD_LIBRARY_PATH=./build ./build/c_example_dlopen

.PHONY: all clean library run