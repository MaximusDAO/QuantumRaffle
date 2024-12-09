require('@nomicfoundation/hardhat-toolbox');
require('dotenv').config()
require("@nomicfoundation/hardhat-toolbox");


module.exports = {
	solidity: {
		version: "0.8.22",
		settings: {
			optimizer: {
				enabled: true
			}
		}
	},
	allowUnlimitedContractSize: true,
	networks: {
		hardhat: {
			chainId: 8008135,
			forking: {
				// Custom Chain ID
				url: "https://rpc.pulsechain.com",
			},
			accounts: { accountsBalance: "9999999999910000000000000000000000" }
		},
		
	},
	etherscan: {
		apiKey: "ASDC"
	},
	paths: {
		artifacts: '../frontend/artifacts'
	}
}