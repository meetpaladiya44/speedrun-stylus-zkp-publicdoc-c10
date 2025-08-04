const fs = require('fs');
const path = require('path');
const solc = require('solc');

// Get contract filename from command line arguments
const contractFilename = process.argv[2];

if (!contractFilename) {
  console.error('Usage: node compile-contract.js <contract-filename>');
  console.error('Example: node compile-contract.js aadhaar-verifier.sol');
  process.exit(1);
}

// Read the Solidity contract
const contractPath = path.resolve(__dirname, 'contracts', contractFilename);

if (!fs.existsSync(contractPath)) {
  console.error(`Contract file not found: ${contractPath}`);
  process.exit(1);
}

const source = fs.readFileSync(contractPath, 'utf8');

// Compile the contract
const input = {
  language: 'Solidity',
  sources: {
    [contractFilename]: {
      content: source
    }
  },
  settings: {
    outputSelection: {
      '*': {
        '*': ['*']
      }
    },
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
};

const output = JSON.parse(solc.compile(JSON.stringify(input)));

// Check for compilation errors
if (output.errors) {
  const errors = output.errors.filter(error => error.severity === 'error');
  if (errors.length > 0) {
    console.error('Compilation errors:');
    errors.forEach(error => console.error(error.formattedMessage));
    process.exit(1);
  }
}

// Get contract name from filename (remove .sol extension)
const contractNameBase = path.basename(contractFilename, '.sol');

// Find the first contract in the compilation output
const contracts = output.contracts[contractFilename];
if (!contracts || Object.keys(contracts).length === 0) {
  console.error('No contracts found in compilation output');
  process.exit(1);
}

// Get the first contract (usually there's only one)
const contractName = Object.keys(contracts)[0];
const compiledContract = contracts[contractName];

if (!compiledContract) {
  console.error(`Contract ${contractName} not found in compilation output`);
  process.exit(1);
}

// Create build directory if it doesn't exist
const buildDir = path.resolve(__dirname, 'build');
if (!fs.existsSync(buildDir)) {
  fs.mkdirSync(buildDir, { recursive: true });
}

// Write the binary and ABI files
const binFilename = `contracts_${contractNameBase}_sol_${contractName}.bin`;
const abiFilename = `contracts_${contractNameBase}_sol_${contractName}.abi`;

fs.writeFileSync(
  path.join(buildDir, binFilename),
  compiledContract.evm.bytecode.object
);

fs.writeFileSync(
  path.join(buildDir, abiFilename),
  JSON.stringify(compiledContract.abi, null, 2)
);

console.log(`${contractName} contract compiled successfully!`);
console.log(`Binary saved to: build/${binFilename}`);
console.log(`ABI saved to: build/${abiFilename}`); 