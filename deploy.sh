#!/bin/bash

# Deployment script for Garden contracts
# This script runs all deployment scripts in sequence:
# 1. RegisterUtilityFacets.s.sol
# 2. CreateGarden.s.sol
# 3. UpgradeGarden.s.sol
# 4. MintNFT.s.sol

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default network (can be overridden with --network flag)
NETWORK="${NETWORK:-localhost}"
BROADCAST="${BROADCAST:-true}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --no-broadcast)
            BROADCAST="false"
            shift
            ;;
        --help)
            echo "Usage: $0 [--network NETWORK] [--no-broadcast]"
            echo ""
            echo "Options:"
            echo "  --network NETWORK    Network to deploy to (default: localhost)"
            echo "                       Options: localhost, arbitrum, mainnet, sepolia, etc."
            echo "  --no-broadcast       Simulate only, don't broadcast transactions"
            echo "  --help               Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if required environment variables are set
if [ -z "$PRIVATE_KEY_ANVIL" ]; then
    echo -e "${YELLOW}Warning: PRIVATE_KEY_ANVIL environment variable is not set${NC}"
fi

if [ -z "$SALT" ]; then
    echo -e "${YELLOW}Warning: SALT environment variable is not set${NC}"
fi

# Function to run a script
run_script() {
    local script_name=$1
    local script_path="script/deploy/${script_name}"
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Running: ${script_name}${NC}"
    echo -e "${GREEN}========================================${NC}\n"
    
    if [ "$BROADCAST" = "true" ]; then
        forge script "$script_path" --rpc-url "$NETWORK" --broadcast -vvv
    else
        forge script "$script_path" --rpc-url "$NETWORK" -vvv
    fi
    
    if [ $? -ne 0 ]; then
        echo -e "\n${RED}Error: Failed to run ${script_name}${NC}"
        exit 1
    fi
    
    echo -e "\n${GREEN}✓ Successfully completed: ${script_name}${NC}\n"
}

# Main deployment sequence
echo -e "${GREEN}Starting deployment sequence on network: ${NETWORK}${NC}"
echo -e "${GREEN}Broadcast mode: ${BROADCAST}${NC}\n"

# 1. Register Utility Facets
run_script "RegisterUtilityFacets.s.sol"

# 2. Create Garden
run_script "CreateGarden.s.sol"

# 3. Upgrade Garden
run_script "UpgradeGarden.s.sol"

# 4. Mint NFT
run_script "MintNFT.s.sol"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}All deployment scripts completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}\n"
