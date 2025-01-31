const { ethers } = require("hardhat");

const contractAddress = "0x162A433068F51e18b7d13932F27e66a3f99E6890";

const num_runs = 900;


async function main() {
    try {
        const provider = new ethers.JsonRpcProvider('http://127.0.0.1:8545');
        let signers = await ethers.getSigners();
        console.log(`Running ${num_runs} simulations...`);
        const TheButtonABI = require("../artifacts/contracts/TheButton.sol/QuantumRaffle.json").abi;
        const contract = new ethers.Contract(contractAddress, TheButtonABI, signers[0]);
        let a = await provider.getBalance(signers[0].getAddress());
        let c = await contract.getNumWinners(1);
        
        await contract.clearLeftoverAdoptionBonus(1);
        let b = await provider.getBalance(signers[0].getAddress());
        console.log(d);
        console.log(b-a);
    } catch (error) {
        console.error("Error:", error);
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });