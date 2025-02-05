const { ethers } = require("hardhat");

const contractAddress = "0x8731d45ff9684d380302573cCFafd994Dfa7f7d3";

const num_runs = 1000000000;
function isDivisibleByPowerOf10(num) {
    // Skip if number is 0 since it's divisible by everything
    if (num === 0n) return true;

    // Convert to string to remove trailing zeros and check if remaining decimal is 1
    const numStr = num.toString();
    return /^10*$/.test(numStr);
}

async function main() {
    try {
        let signers = await ethers.getSigners();
        const TheButtonABI = require("../artifacts/contracts/QuantumRaffle.sol/QuantumRaffle.json").abi;
        const contract = new ethers.Contract(contractAddress, TheButtonABI, signers[0]);
        const gameId = await contract.gameId();
        let numWinners =1;
        let entryAmount =await contract.entryAmount();
        for (let i = 0; i < num_runs; i++) {
            // Get random signer between index 1-19 (keeping 0 as deployer)
            const randomSignerIndex = Math.floor(Math.random() * 15) + 4;
            const signer = signers[randomSignerIndex];

            
            let mult;
            if(numWinners<2){
                mult =BigInt(10);
            }
            else {
                mult = BigInt(1);
            }
            
            const tx = await signer.sendTransaction({
                to: contractAddress,
                value: entryAmount * mult * 10n,
                data: "0x"
            });
            //await new Promise(resolve => setTimeout(resolve, 10)); // Wait 1 second
            if(i % 1000 === 0) {
                console.log(i);
            }
            const receipt = await tx.wait();
            
            
        }
        
        console.log("\nAll simulations completed successfully");
        
    } catch (error) {
        console.error("Error running simulation:", error);
        process.exit(1);
    }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });