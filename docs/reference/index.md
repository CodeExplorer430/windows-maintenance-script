# Cmdlet Reference

Detailed documentation for all framework cmdlets.

## Core Modules

| Module | Description |
|--------|-------------|
| `WindowsMaintenance` | The orchestrator module that manages the execution flow. |

## Feature Modules

| Module | Purpose |
|--------|---------|
| `BackupMaintenance` | Manages System Restore Points and critical file backups. |
| `BloatwareRemoval` | Removes unwanted UWP and system applications. |
| `DeveloperMaintenance` | Cleans caches for dev tools (NPM, Docker, Python, etc.). |
| `DiskMaintenance` | Comprehensive system and browser cleanup. |
| `EventLogMaintenance` | Manages and archives Windows Event Logs. |
| `GPUMaintenance` | Optimizes GPU driver caches and logs. |
| `MultimediaMaintenance` | Cleans professional creative software caches. |
| `NetworkMaintenance` | Network optimization and diagnostics. |
| `PerformanceOptimization` | Startup and system resource optimization. |
| `PrivacyMaintenance` | Telemetry reduction and privacy hardening. |
| `SecurityScans` | Orchestrates Windows Defender and security checks. |
| `SystemHealthRepair` | Runs DISM and SFC system repairs. |
| `SystemReporting` | Generates consolidated maintenance reports. |
| `SystemUpdates` | Manages Windows and Store updates. |
| `TaskScheduler` | Automates the maintenance schedule. |

## Common Infrastructure

| Module | Functionality |
|--------|---------------|
| `Analytics` | Tracks performance metrics and historical data. |
| `Database` | SQLite backend for metrics and history. |
| `Logging` | Unified logging system with stream support. |
| `SafeExecution` | Version-aware parallel execution and error handling. |
| `SecretManager` | Secure credential management. |
| `SystemDetection` | Hardware and environment discovery. |
