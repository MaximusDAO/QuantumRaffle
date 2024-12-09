const hre = require("hardhat");

async function main() {
	const fee = hre.ethers.utils.parseEther("100000"); // Converts 0.1 ETH to wei
	const Contract = await hre.ethers.getContractFactory("TheButton");
	const contract = await Contract.deploy(fee);

	await contract.deployed();

	console.log("TheButton deployed to:", contract.address);

	// Get test accounts
	const [owner, ...accounts] = await hre.ethers.getSigners();
	let oldId = 0;
	// Helper function to sleep for random duration
	const randomSleep = async () => {
		const sleepTime = Math.floor(Math.random() * (330- 1) + 1) * 1000; // Random between 1s and 2m
		await hre.network.provider.send("evm_increaseTime", [sleepTime/1000]);
		await hre.network.provider.send("evm_mine");
	};
	let latestLastTime = 0;
	// Loop through accounts and interact with contract
	for (let j = 0; j<10; j++){
		for (let i = 0; i < 10; i++) {
			await randomSleep();
			
			
			
			// Send transaction
			const tx = await accounts[i].sendTransaction({
				to: contract.address,
				value: fee
			});
			await tx.wait();
			
			
			


			// Get contract state
			const currentGameId = await contract.gameId();
			try {
				const claimTx = await contract.connect(accounts[i]).claimPrize(currentGameId);
				await claimTx.wait();
			} catch (error) {
				console.log(`Failed to claim prize for game ${currentGameId}: ${error.message}`);
			}
			if (currentGameId.toString() != oldId.toString()){
			
				console.log("NewGame ID:", currentGameId.toString());

				console.log("-".repeat(50));
			}
			
			const lastTime = await contract.lastTimestamp(currentGameId);
			
			const latestPlayer = await contract.latestEntrant(currentGameId);
			const totalEntries = await contract.entries(currentGameId);

			console.log("\nTransaction completed:");
			console.log("Player:", accounts[i].address);
			
			console.log("Last Button Press:", new Date(lastTime.toNumber() * 1000).toISOString());
			console.log("Seconds since last press:", (lastTime.toNumber() - latestLastTime));
			console.log("Latest Player:", latestPlayer);
			console.log("Total Pot:", hre.ethers.utils.formatEther(totalEntries), "ETH");
			console.log("-".repeat(50));
			oldId=currentGameId;
			latestLastTime = lastTime;
		}}
	// loop through gameIds and run claimPrize from the account that won the game
	// Get final game ID to know how many games to process
	const finalGameId = await contract.gameId();
	
	console.log("\nProcessing claims for completed games...");
	
	// Loop through all game IDs
	for (let gameId = 0; gameId <= finalGameId; gameId++) {
		// Get winner address for this game
		const winner = await contract.latestEntrant(gameId);
		
		// Find matching account that corresponds to winner address
		const winningAccount = accounts.find(account => account.address.toLowerCase() === winner.toLowerCase());
		
		if (winningAccount) {
			try {
				// Check if already claimed
				const claimed = await contract.hasClaimed(gameId);
				if (!claimed) {
					// Submit claim transaction from winning account
					const claimTx = await contract.connect(winningAccount).claimPrize(gameId);
					await claimTx.wait();
					const entries = await contract.entries(gameId);
					console.log(`Successfully claimed prize of ${hre.ethers.utils.formatEther(entries)} ETH for game ${gameId} by ${winner}`);
					try {
						const claimTx = await contract.connect(winningAccount).claimPrize(gameId);
						await claimTx.wait();
					} catch (error) {
						console.log(`Failed to repeat claim prize for game ${gameId}: ${error.message}`); }
				} else {
					console.log(`Prize already claimed for game ${gameId}`);
				}
			} catch (error) {
				console.log(`Failed to claim prize for game ${gameId}: ${error.message}`);
			}
		} else {
			console.log(`Could not find matching account for winner ${winner} of game ${gameId}`);
		}
	}
}

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});