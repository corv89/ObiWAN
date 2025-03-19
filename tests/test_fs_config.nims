# Test-specific configuration for fs.nim tests
# Override mbedTLS linking

# Don't use mbedTLS for this test
switch("define", "skipMbedTLS")
switch("passL", "")  # Clear linker options that would include mbedTLS