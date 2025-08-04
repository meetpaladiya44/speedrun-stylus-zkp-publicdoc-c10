const fs = require('fs');
const path = require('path');
const solc = require('solc');

// Read the Solidity contract
const contractPath = path.resolve(__dirname, 'contracts/aadhaar-verifier.sol');
const source = fs.readFileSync(contractPath, 'utf8');

// Compile the contract
const input = {
  language: 'Solidity',
  sources: {
    'aadhaar-verifier.sol': {
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

// Extract the compiled contract
const contractName = 'Groth16Verifier';
const compiledContract = output.contracts['aadhaar-verifier.sol'][contractName];

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
fs.writeFileSync(
  path.join(buildDir, `contracts_aadhaar-verifier_sol_${contractName}.bin`),
  compiledContract.evm.bytecode.object
);

fs.writeFileSync(
  path.join(buildDir, `contracts_aadhaar-verifier_sol_${contractName}.abi`),
  JSON.stringify(compiledContract.abi, null, 2)
);

console.log('Aadhaar verifier contract compiled successfully!');
console.log(`Binary saved to: build/contracts_aadhaar-verifier_sol_${contractName}.bin`);
console.log(`ABI saved to: build/contracts_aadhaar-verifier_sol_${contractName}.abi`); 