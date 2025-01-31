const { ethers } = require("hardhat");

const contractAddress = "0x9D3999af03458c11C78F7e6C0fAE712b455D4e33";

const num_runs = 100000;
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
        const TheButtonABI = require("../artifacts/contracts/TheButton.sol/QuantumRaffle.json").abi;
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
                value: entryAmount * mult * 5n,
                data: "0x"
            });
            await new Promise(resolve => setTimeout(resolve, 1000)); // Wait 1 second
            
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