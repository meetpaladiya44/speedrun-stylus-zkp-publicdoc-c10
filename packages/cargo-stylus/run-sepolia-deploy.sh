#!/bin/bash

if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Exit on error
set -e

# Arbitrum Sepolia RPC URL
SEPOLIA_RPC_URL="https://sepolia-rollup.arbitrum.io/rpc"

# Check for PRIVATE_KEY environment variable
if [[ -z "$PRIVATE_KEY" ]]; then
  echo "Error: PRIVATE_KEY environment variable is not set."
  echo "Please set your private key: export PRIVATE_KEY=your_private_key_here"
  exit 1
fi

# Check for required tools
for cmd in cast node curl; do
  if ! command -v $cmd &> /dev/null; then
    echo "Error: $cmd is not installed."
    exit 1
  fi
done

# Check if node_modules exists, if not install dependencies
if [[ ! -d "node_modules" ]]; then
  echo "Installing Node.js dependencies..."
  npm install
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to install Node.js dependencies"
    exit 1
  fi
fi

# Check if we can connect to Arbitrum Sepolia
echo "Checking connection to Arbitrum Sepolia..."
curl_output=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
  "$SEPOLIA_RPC_URL")

if [[ "$curl_output" != *"result"* ]]; then
    echo "Error: Cannot connect to Arbitrum Sepolia RPC"
    echo "Curl output: $curl_output"
    exit 1
fi
echo "Connected to Arbitrum Sepolia!"

# Derive deployer address from private key
deployer_address=$(cast wallet address --private-key "$PRIVATE_KEY")

echo "Deployer address: $deployer_address"

# Compile the Solidity contract
echo "Compiling Solidity contract..."
node compile-aadhaar-contract.js

if [[ $? -ne 0 ]]; then
    echo "Error: Solidity compilation failed"
    exit 1
fi

# Extract compiled contract binary and ABI
# Assuming the contract name is Groth16Verifier based on the file pattern; adjust if necessary
contract_bin=$(cat build/contracts_aadhaar-verifier_sol_Groth16Verifier.bin)
contract_abi=$(cat build/contracts_aadhaar-verifier_sol_Groth16Verifier.abi)

if [[ -z "$contract_bin" || -z "$contract_abi" ]]; then
    echo "Error: Compilation output not found"
    exit 1
fi

echo "Solidity contract compiled successfully."

# Deploy the contract to Arbitrum Sepolia
echo "Deploying the Solidity contract to Arbitrum Sepolia..."
deploy_output=$(cast send --private-key "$PRIVATE_KEY" \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --create 0x$contract_bin)

# Extract deployment transaction hash using robust pattern
deployment_tx=$(echo "$deploy_output" | grep -i "transaction\|tx" | grep -oE '0x[a-fA-F0-9]{64}' | head -1)

# Extract contract address using robust pattern
contract_address=$(echo "$deploy_output" | grep "contractAddress" | grep -oE '0x[a-fA-F0-9]{40}')

# Fallback extraction if above patterns don't work
if [[ -z "$deployment_tx" ]]; then
    deployment_tx=$(echo "$deploy_output" | grep -oE '0x[a-fA-F0-9]{64}' | head -1)
fi

if [[ -z "$contract_address" ]]; then
    contract_address=$(echo "$deploy_output" | grep -i "contract\|deployed" | grep -oE '0x[a-fA-F0-9]{40}' | head -1)
fi

# Verify extraction was successful
if [[ -z "$deployment_tx" ]]; then
    echo "Error: Could not extract deployment transaction hash from output"
    echo "Deploy output: $deploy_output"
    exit 1
fi

if [[ -z "$contract_address" ]]; then
    echo "Error: Could not extract contract address from output"
    echo "Deploy output: $deploy_output"
    exit 1
fi

echo "Solidity contract deployed successfully!"
echo "Transaction hash: $deployment_tx"
echo "Contract address: $contract_address"

# Output ABI for future use
echo "$contract_abi" > build/aadhaar-verifierABI.json
echo "ABI saved to build/aadhaar-verifierABI.json"

# Create build directory if it doesn't exist (redundant if already created by solcjs, but safe)
mkdir -p build

# Save deployment info to JSON file
echo "{
  \"network\": \"arbitrum-sepolia\",
  \"deployer_address\": \"$deployer_address\",
  \"contract_address\": \"$contract_address\",
  \"transaction_hash\": \"$deployment_tx\",
  \"rpc_url\": \"$SEPOLIA_RPC_URL\",
  \"deployment_time\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
}" > build/solidity-deployment-info.json

echo "Deployment info saved to build/solidity-deployment-info.json"
echo "Deployment completed successfully on Arbitrum Sepolia!"