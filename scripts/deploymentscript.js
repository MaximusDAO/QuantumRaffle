const { ethers } = require("hardhat");

async function main() {
  const ENTRY_AMOUNT = ethers.parseEther("200000");
  const GAME_DURATION = 60*30;

  // Get signers
  const signers = await ethers.getSigners();
  
  // Deploy contract
  console.log("Deploying Quantum Raffle...");
  const GameContract = await ethers.getContractFactory("QuantumRaffle");
  const game = await GameContract.deploy(ENTRY_AMOUNT, GAME_DURATION);
  await game.waitForDeployment();
  
  const contractAddress = await game.getAddress();
  console.log("Contract deployed to:", contractAddress);

  // Create contract instance
  const TheButtonABI = require("../artifacts/contracts/TheButton.sol/QuantumRaffle.json").abi;
  const contract = new ethers.Contract(contractAddress, TheButtonABI, signers[0]);
  //await contract.startGame();
  // Log initial state
  console.log("\nInitial contract state:");
  console.log("Entry Amount:", ethers.formatEther(ENTRY_AMOUNT), "ETH");
  console.log("Game Duration:", GAME_DURATION, "seconds");
  
  const gameId = await contract.gameId();
  console.log("\nGame Details:");
  console.log("Game ID:", gameId);
  console.log("Entrant Count:", await contract.entrantCount(gameId));
  console.log("Prize Pool:", ethers.formatEther(await contract.prizePool(gameId)), "ETH");
  console.log("Prize Per Winner:", ethers.formatEther(await contract.prizePerWinner(gameId)), "ETH");
  console.log("Number of Winners:", await contract.getNumWinners(gameId));
  console.log("Last Timestamp:", await contract.lastTimestamp(gameId));
  
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
