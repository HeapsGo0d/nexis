#!/bin/bash
set -e

export E2E_SHUTDOWN_TIMEOUT=${E2E_SHUTDOWN_TIMEOUT:-15}
export SERVICE_HEALTH_TIMEOUT=${SERVICE_HEALTH_TIMEOUT:-10}
export SERVICE_SHUTDOWN_TIMEOUT=${SERVICE_SHUTDOWN_TIMEOUT:-10}
echo "Running Docker Build Test..."
./nexis/tests/test_docker_build.sh
echo "Running Service Startup Test..."
./nexis/tests/test_service_startup.sh
echo "Running End-to-End Test..."
./nexis/tests/test_end_to_end.sh
echo "Running Concurrent Downloads Test..."
./nexis/tests/test_concurrent_downloads.sh
echo "Running Disk Space Test..."
./nexis/tests/test_disk_space.sh
echo "Running Network Interruption Test..."
./nexis/tests/test_network_interruption.sh
echo "Running Memory Pressure Test..."
./nexis/tests/test_memory_pressure.sh
echo "Running GPU Memory Exhaustion Test..."
./nexis/tests/test_gpu_memory_exhaustion.sh
echo "All tests passed!"