require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      evmVersion: "cancun",  // Set EVM version to Cancun
      viaIR: true  // Enable IR-based code generation
  }},
  networks: {
    hardhat: {
      chainId: 80085,
      accounts: {
        accountsBalance: "10000000000000000000000000000000000" // Default balance of 100,000 ETH in wei
      }
    }
  }
  
};
