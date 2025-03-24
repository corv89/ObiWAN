## ObiWAN Configuration Module
## 
## This module provides configuration loading and management for ObiWAN.
## It supports loading configuration from TOML files, environment variables,
## and command-line arguments.

import parsetoml
import os
import obiwan/debug

type
  ConfigError* = object of CatchableError
    ## Exception raised for configuration errors

  ServerConfig* = object
    ## Configuration for a Gemini server
    address*: string       ## Bind address (e.g., "0.0.0.0" or "::")
    port*: int            ## Port to listen on (default: 1965)
    certFile*: string     ## Path to server certificate file
    keyFile*: string      ## Path to server private key file
    reuseAddr*: bool      ## Allow reuse of local addresses
    reusePort*: bool      ## Allow multiple bindings to same port
    useIPv6*: bool        ## Use IPv6 instead of IPv4
    sessionId*: string    ## Optional session ID for TLS
    docRoot*: string      ## Document root directory for serving files
    logRequests*: bool    ## Whether to log all requests
    maxRequestLength*: int ## Maximum request length in bytes

  ClientConfig* = object
    ## Configuration for a Gemini client
    certFile*: string     ## Path to client certificate for auth
    keyFile*: string      ## Path to client private key for auth
    maxRedirects*: int    ## Maximum number of redirects to follow
    timeout*: int         ## Connection timeout in seconds
    userAgent*: string    ## User agent string (for debugging)

  LogConfig* = object
    ## Logging configuration
    level*: int           ## Verbosity level (0-3)
    file*: string         ## Log file path (empty for stdout)
    timestamp*: bool      ## Include timestamps in log entries

  Config* = object
    ## Main configuration object
    server*: ServerConfig   ## Server configuration
    client*: ClientConfig   ## Client configuration
    log*: LogConfig         ## Logging configuration

proc defaultConfig*(): Config =
  ## Creates a default configuration with sensible defaults
  result = Config(
    server: ServerConfig(
      address: "",         # Default to all interfaces
      port: 1965,          # Standard Gemini port
      certFile: "cert.pem",
      keyFile: "privkey.pem",
      reuseAddr: true,
      reusePort: false,
      useIPv6: false,
      sessionId: "",      # Will be randomly generated
      docRoot: "./content",
      logRequests: true,
      maxRequestLength: 1024
    ),
    client: ClientConfig(
      certFile: "",
      keyFile: "",
      maxRedirects: 5,
      timeout: 30,
      userAgent: "ObiWAN/0.5.0"
    ),
    log: LogConfig(
      level: 0,             # Default to minimal logging
      file: "",            # Default to stdout
      timestamp: true
    )
  )

proc loadConfig*(configFile: string): Config =
  ## Loads configuration from a TOML file
  ##
  ## This function loads and parses a TOML configuration file,
  ## applying the values to a Config object. If the file doesn't exist
  ## or can't be parsed, it raises a ConfigError.
  ##
  ## Parameters:
  ##   configFile: Path to the TOML configuration file
  ##
  ## Returns:
  ##   A Config object with values from the file
  ##
  ## Raises:
  ##   ConfigError: If the file doesn't exist or can't be parsed
  
  # Start with default configuration
  result = defaultConfig()
  
  # Check if file exists
  if not fileExists(configFile):
    raise newException(ConfigError, "Configuration file not found: " & configFile)
  
  # Parse the TOML file
  var toml: TomlValueRef
  try:
    toml = parsetoml.parseFile(configFile)
  except:
    raise newException(ConfigError, "Failed to parse config file: " & getCurrentExceptionMsg())
  
  # Server section
  if toml.hasKey("server"):
    let server = toml["server"]
    if server.hasKey("address"):
      result.server.address = server["address"].getStr()
    if server.hasKey("port"):
      result.server.port = server["port"].getInt().int
    if server.hasKey("cert_file"):
      result.server.certFile = server["cert_file"].getStr()
    if server.hasKey("key_file"):
      result.server.keyFile = server["key_file"].getStr()
    if server.hasKey("reuse_addr"):
      result.server.reuseAddr = server["reuse_addr"].getBool()
    if server.hasKey("reuse_port"):
      result.server.reusePort = server["reuse_port"].getBool()
    if server.hasKey("use_ipv6"):
      result.server.useIPv6 = server["use_ipv6"].getBool()
    if server.hasKey("session_id"):
      result.server.sessionId = server["session_id"].getStr()
    if server.hasKey("doc_root"):
      result.server.docRoot = server["doc_root"].getStr()
    if server.hasKey("log_requests"):
      result.server.logRequests = server["log_requests"].getBool()
    if server.hasKey("max_request_length"):
      result.server.maxRequestLength = server["max_request_length"].getInt().int
  
  # Client section
  if toml.hasKey("client"):
    let client = toml["client"]
    if client.hasKey("cert_file"):
      result.client.certFile = client["cert_file"].getStr()
    if client.hasKey("key_file"):
      result.client.keyFile = client["key_file"].getStr()
    if client.hasKey("max_redirects"):
      result.client.maxRedirects = client["max_redirects"].getInt().int
    if client.hasKey("timeout"):
      result.client.timeout = client["timeout"].getInt().int
    if client.hasKey("user_agent"):
      result.client.userAgent = client["user_agent"].getStr()
  
  # Log section
  if toml.hasKey("log"):
    let log = toml["log"]
    if log.hasKey("level"):
      result.log.level = log["level"].getInt().int
    if log.hasKey("file"):
      result.log.file = log["file"].getStr()
    if log.hasKey("timestamp"):
      result.log.timestamp = log["timestamp"].getBool()

proc findConfigFile*(): string =
  ## Attempts to find a configuration file in standard locations:
  ## 1. ./obiwan.toml (current directory)
  ## 2. ~/.config/obiwan/config.toml (user config)
  ## 3. /etc/obiwan/config.toml (system config)
  ##
  ## Returns the path to the first file found, or an empty string if none exists.
  
  # Check current directory
  if fileExists("obiwan.toml"):
    return "obiwan.toml"
  
  # Check user config directory
  let userConfig = getHomeDir() / ".config/obiwan/config.toml"
  if fileExists(userConfig):
    return userConfig
  
  # Check system config directory
  const systemConfig = "/etc/obiwan/config.toml"
  if fileExists(systemConfig):
    return systemConfig
  
  return ""

proc initializeLogging*(config: Config) =
  ## Initializes logging based on configuration
  ##
  ## This function sets up the logging verbosity and output destination
  ## based on the configuration.
  ##
  ## Parameters:
  ##   config: The Config object containing logging settings
  
  # Set verbosity level (no-op in current implementation to avoid linking issues)
  debug.setVerbosityLevel(config.log.level)
  
  # TODO: Implement log file output when needed
  # For now, all logs go to stdout/stderr

proc saveConfig*(config: Config, filePath: string) =
  ## Saves the current configuration to a TOML file
  ##
  ## This function serializes the Config object to TOML format and
  ## writes it to the specified file. If the file can't be written,
  ## it raises a ConfigError.
  ##
  ## Parameters:
  ##   config: The Config object to save
  ##   filePath: Path where the file should be written
  ##
  ## Raises:
  ##   ConfigError: If the file can't be written
  
  var tomlStr = "# ObiWAN Gemini Server Configuration\n\n"
  
  # Server section
  tomlStr &= "[server]\n"
  tomlStr &= "address = \"" & config.server.address & "\"\n"
  tomlStr &= "port = " & $config.server.port & "\n"
  tomlStr &= "cert_file = \"" & config.server.certFile & "\"\n"
  tomlStr &= "key_file = \"" & config.server.keyFile & "\"\n"
  tomlStr &= "reuse_addr = " & $config.server.reuseAddr & "\n"
  tomlStr &= "reuse_port = " & $config.server.reusePort & "\n"
  tomlStr &= "use_ipv6 = " & $config.server.useIPv6 & "\n"
  tomlStr &= "session_id = \"" & config.server.sessionId & "\"\n"
  tomlStr &= "doc_root = \"" & config.server.docRoot & "\"\n"
  tomlStr &= "log_requests = " & $config.server.logRequests & "\n"
  tomlStr &= "max_request_length = " & $config.server.maxRequestLength & "\n\n"
  
  # Client section
  tomlStr &= "[client]\n"
  tomlStr &= "cert_file = \"" & config.client.certFile & "\"\n"
  tomlStr &= "key_file = \"" & config.client.keyFile & "\"\n"
  tomlStr &= "max_redirects = " & $config.client.maxRedirects & "\n"
  tomlStr &= "timeout = " & $config.client.timeout & "\n"
  tomlStr &= "user_agent = \"" & config.client.userAgent & "\"\n\n"
  
  # Log section
  tomlStr &= "[log]\n"
  tomlStr &= "level = " & $config.log.level & "\n"
  tomlStr &= "file = \"" & config.log.file & "\"\n"
  tomlStr &= "timestamp = " & $config.log.timestamp & "\n"
  
  # Write to file
  try:
    writeFile(filePath, tomlStr)
  except:
    raise newException(ConfigError, "Failed to write config file: " & getCurrentExceptionMsg())

proc resolveConfigFile*(configPath = ""): string =
  ## Resolves the configuration file path
  ##
  ## If configPath is provided and exists, it's used.
  ## Otherwise, try to find a config file in standard locations.
  ## If no config file is found, return an empty string.
  
  if configPath != "" and fileExists(configPath):
    return configPath
  
  return findConfigFile()

proc loadOrCreateConfig*(configPath = ""): Config =
  ## Loads an existing config or creates a default one
  ##
  ## If configPath is provided and exists, it's loaded.
  ## Otherwise, try to find a config file in standard locations.
  ## If no config file is found, a default config is returned.
  ##
  ## Returns:
  ##   A Config object loaded from a file or with default values
  
  let resolvedPath = resolveConfigFile(configPath)
  
  if resolvedPath != "":
    try:
      result = loadConfig(resolvedPath)
      debug("Loaded configuration from " & resolvedPath)
      return result
    except:
      debug("Failed to load configuration: " & getCurrentExceptionMsg())
  
  # Return default config if no file found or loading failed
  debug("Using default configuration")
  return defaultConfig()
