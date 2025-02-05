const { expect } = require("chai");
const { ethers } = require("hardhat");


describe("QuantumRaffle", function () {
    let game;
    let owner;
    let addr1;
    let b;
    let signers
    const ENTRY_AMOUNT = ethers.parseEther("200000");
    const GAME_DURATION = 1800;

    beforeEach(async function () {
        signers = await ethers.getSigners();
        const GameContract = await ethers.getContractFactory("QuantumRaffle");
        game = await GameContract.deploy(ENTRY_AMOUNT, GAME_DURATION);
    
    });

    describe("⚡️⚡️⚡️ Start Rules", function ()
    { 
      it("Non host address can not start the game.", async function() {
        // Non-host should fail
        let nonHost = signers[4];
        await expect(nonHost.sendTransaction({
          to: game.target,
          value: 10n * ENTRY_AMOUNT
        })).to.be.reverted;
      })
      it("Host can not start game without correct deposit amount.", async function() {
        // Host with wrong amount should fail
        await expect(signers[0].sendTransaction({
            to: game.target,
            value: 9n * ENTRY_AMOUNT
          })).to.be.reverted;
          await expect(signers[0].sendTransaction({
            to: game.target,
            value: 11n * ENTRY_AMOUNT 
          })).to.be.reverted;
      })
      it ("Only host can start game with deposit 10x the normal entry amount.", async function() {
        // Host with correct amount should succeed
        
        await expect(signers[0].sendTransaction({
            to: game.target,
            value: 10n * ENTRY_AMOUNT
        })).to.not.be.reverted;
        // Moving this test outside since it statements can't be nested
        });
        
      it("GameId should increment after game start", async function () {
        // Start game as host
        await signers[0].sendTransaction({
            to: game.target,
            value: 10n * ENTRY_AMOUNT
        });
        expect(await game.gameId()).to.equal(1);
    });
      
      it("First 8 deposits after host must be 10x normal amount and must be allocated to prize pool accordingly", async function() {
        // Host starts game
        await signers[0].sendTransaction({
          to: game.target, 
          value: 10n * ENTRY_AMOUNT
        });

        // First 8 players must pay 10x
        for(let i = 1; i <= 8; i++) {
          const player = signers[i];
          // Should fail with normal amount
          await expect(player.sendTransaction({
            to: game.target,
            value: ENTRY_AMOUNT
          })).to.be.reverted;
          await expect(player.sendTransaction({
            to: game.target,
            value: 20n*ENTRY_AMOUNT
          })).to.be.reverted;
          // Log X symbol for failed transaction
          // Should succeed with 10x amount
          await expect(player.sendTransaction({
            to: game.target,
            value: 10n * ENTRY_AMOUNT
          })).to.not.be.reverted;
        }
        // Verify prize pool and adoption bonus pool amounts after first 9 entries
        expect(await game.prizePool(1)).to.equal(9n * 10n * ENTRY_AMOUNT * 8n / 10n); // 80% of total entries

        // Check adoption bonus pools
        expect(await game.adoptionBonusPrizePool(1, 0)).to.equal(0);
        expect(await game.adoptionBonusPrizePool(1, 1)).to.equal(0);
        expect(await game.adoptionBonusPrizePool(1, 2)).to.equal(9n * 10n * ENTRY_AMOUNT * 2n / 10n); // 20% of total entries
        expect(await game.adoptionBonusPrizePool(1, 3)).to.equal(0);
        

        // 9th player can pay normal amount
        const player9 = signers[9];
        await expect(player9.sendTransaction({
          to: game.target,
          value: ENTRY_AMOUNT
        })).to.not.be.reverted;
      });
    });
    describe("⚡️⚡️⚡️ Game Progression", function (){
        it("Should ensure claiming rules. " , async function() {
            // numWinners(gameId) is the cohortID that gets "filled up when deposits come in."
        let gameId = await game.gameId();
        // Start game with host
        await signers[0].sendTransaction({
            to: game.target,
            value: 10n * ENTRY_AMOUNT
        });

        // First 8 players pay 10x
        for(let i = 1; i <= 8; i++) {
            await signers[i].sendTransaction({
                to: game.target,
                value: 10n * ENTRY_AMOUNT
            });
        }

        // 9th player pays normal amount
        await signers[9].sendTransaction({
            to: game.target,
            value: ENTRY_AMOUNT
        });

        

        // Add entries in batches of 10 up to 1020
        for(let i = 1; i < 1020; i++) {
            
            await signers[i % 20].sendTransaction({
                to: game.target,
                value: 10n * ENTRY_AMOUNT // 10 entries per tx
            });
            if (i==3) {
                console.log("Testing claim before 100 entries - should fail");
                // Verify claiming fails when entries < 100
                await expect(
                    game.batchClaimAdoptionBonusPrize(1, [{cohortId: 2, entrantId: 5}]), "SDFSDFSF"
                ).to.be.reverted;
            }

            // At 100 entries, test claiming for single digit IDs from cohort 2
            if(i === 10) { // 100 entries reached
                console.log("100 entries reached - testing cohort 2 claims");
                // Should succeed for single digit ID
                // Calculate expected adoption bonus pool for cohort 2
                const expectedPool = (9n * 10n * ENTRY_AMOUNT * 2n / 10n) + (90n * ENTRY_AMOUNT * 2n / 10n);
                expect(await game.adoptionBonusPrizePool(1, 2)).to.equal(expectedPool);
                console.log(`Expected pool for cohort 2: ${ethers.formatEther(expectedPool)} PLS`);

               

                let a = await ethers.provider.getBalance(game.target);
                console.log("Claiming adoption bonus for single digit IDs in cohort 2");
                await expect(game.batchClaimAdoptionBonusPrize(1, [
                    {cohortId: 2, entrantId: 1},
                    {cohortId: 2, entrantId: 2}, 
                    {cohortId: 2, entrantId: 3},
                    {cohortId: 2, entrantId: 4},
                    {cohortId: 2, entrantId: 5},
                    {cohortId: 2, entrantId: 6},
                    {cohortId: 2, entrantId: 7},
                    {cohortId: 2, entrantId: 8},
                    {cohortId: 2, entrantId: 9}
                ])).to.not.be.reverted;
                let b = await ethers.provider.getBalance(game.target);
                // Verify each entrant received their share
                let totalPaid = a-b;
                
                console.log(`Total paid out for cohort 2: ${ethers.formatEther(totalPaid)} PLS`);

                // Verify total paid matches expected pool
                expect(totalPaid).to.be.closeTo(expectedPool, 1000000000000000n);
                console.log("Testing invalid claims - should all fail");
                await expect(
                    game.batchClaimAdoptionBonusPrize(1, [{cohortId: 2, entrantId: 5}])
                ).to.be.reverted;
                // Should fail for double digit ID
                await expect(
                    game.batchClaimAdoptionBonusPrize(1, [{cohortId: 2, entrantId: 15}])
                ).to.be.reverted;
                await expect(
                    game.batchClaimAdoptionBonusPrize(1, [{cohortId: 2, entrantId: 0}])
                ).to.be.reverted;
                await expect(
                    game.batchClaimAdoptionBonusPrize(1, [{cohortId: 3, entrantId: 15}])
                ).to.be.reverted;
                await expect(
                    game.batchClaimAdoptionBonusPrize(1, [{cohortId: 3, entrantId: 15}])
                ).to.be.reverted;
            }

            if(i === 100) { // 100 entries reached
                console.log("1000 entries reached - testing cohort 3 claims");
                const expectedPool2 =  (900n * ENTRY_AMOUNT * 2n / 10n);
                expect(await game.adoptionBonusPrizePool(1, 3)).to.equal(expectedPool2);
                console.log(`Expected pool for cohort 3: ${ethers.formatEther(expectedPool2)} PLS`);
                
                let c = await ethers.provider.getBalance(game.target);
                console.log("Claiming adoption bonus for single digit IDs in cohort 3");
                await expect(game.batchClaimAdoptionBonusPrize(1, 
                    Array.from({length: 9}, (_, i) => ({
                        cohortId: 3,
                        entrantId: i + 1
                    }))
                )).to.not.be.reverted;
                let a = await ethers.provider.getBalance(game.target);
                let totalPaidSingleDigit = c-a;
                console.log(`Paid out for single digit IDs: ${ethers.formatEther(totalPaidSingleDigit)} PLS`);
                // Claim adoption bonuses for double digit entrants
                console.log("Claiming adoption bonus for double digit IDs in cohort 3");
                await expect(game.batchClaimAdoptionBonusPrize(1, 
                    Array.from({length: 90}, (_, i) => ({
                        cohortId: 3,
                        entrantId: i + 10
                    }))
                )).to.not.be.reverted;
                let b = await ethers.provider.getBalance(game.target);
                let totalPaidDoubleDigit = a-b;
                console.log(`Paid out for double digit IDs: ${ethers.formatEther(totalPaidDoubleDigit)} PLS`);
                expect(totalPaidSingleDigit).to.be.closeTo(totalPaidDoubleDigit, 10000000000000000000n);
                const totalPaid = totalPaidSingleDigit + totalPaidDoubleDigit;
                console.log(`Total paid out for cohort 3: ${ethers.formatEther(totalPaid)} PLS`);
                expect(totalPaid).to.be.closeTo(expectedPool2, 100000000000000000n);
                console.log("Testing invalid claims - should all fail");
                await expect(
                    game.batchClaimAdoptionBonusPrize(1, [{cohortId: 3, entrantId: 5}])
                ).to.be.reverted;
                await expect(
                    game.batchClaimAdoptionBonusPrize(1, [{cohortId: 3, entrantId: 100}])
                ).to.be.reverted;
                await expect(
                    game.batchClaimAdoptionBonusPrize(1, [{cohortId: 3, entrantId: 0}])
                ).to.be.reverted;
                await expect(
                    game.batchClaimAdoptionBonusPrize(1, [{cohortId: 3, entrantId: 15}])
                ).to.be.reverted;

            }
            if(i === 1000) { // 100 entries reached
                console.log("10000 entries reached - testing cohort 4 claims");
                const expectedPool3 =  (9000n * ENTRY_AMOUNT * 2n / 10n);
                expect(await game.adoptionBonusPrizePool(1, 4)).to.equal(expectedPool3);
                console.log(`Expected pool for cohort 4: ${ethers.formatEther(expectedPool3)} PLS`);
                
                let c = await ethers.provider.getBalance(game.target);
                console.log("Claiming adoption bonus for single digit IDs in cohort 4");
                await expect(game.batchClaimAdoptionBonusPrize(1, 
                    Array.from({length: 9}, (_, i) => ({
                        cohortId: 4,
                        entrantId: i + 1
                    }))
                )).to.not.be.reverted;
                let a = await ethers.provider.getBalance(game.target);
                let totalPaidSingleDigit = c-a;
                console.log(`Paid out for single digit IDs: ${ethers.formatEther(totalPaidSingleDigit)} PLS`);
                // Claim adoption bonuses for double digit entrants
                console.log("Claiming adoption bonus for double digit IDs in cohort 4");
                await expect(game.batchClaimAdoptionBonusPrize(1, 
                    Array.from({length: 90}, (_, i) => ({
                        cohortId: 4,
                        entrantId: i + 10
                    }))
                )).to.not.be.reverted;
                let b = await ethers.provider.getBalance(game.target);
                let totalPaidDoubleDigit = a-b;
                console.log(`Paid out for double digit IDs: ${ethers.formatEther(totalPaidDoubleDigit)} PLS`);
                console.log("Claiming adoption bonus for triple digit IDs (100-399) in cohort 4");
                await expect(game.batchClaimAdoptionBonusPrize(1, 
                    Array.from({length: 300}, (_, i) => ({
                        cohortId: 4,
                        entrantId: i + 100
                    }))
                )).to.not.be.reverted;

                console.log("Claiming adoption bonus for triple digit IDs (400-699) in cohort 4");
                await expect(game.batchClaimAdoptionBonusPrize(1, 
                    Array.from({length: 300}, (_, i) => ({
                        cohortId: 4,
                        entrantId: i + 400
                    }))
                )).to.not.be.reverted;

                console.log("Claiming adoption bonus for triple digit IDs (700-999) in cohort 4");
                await expect(game.batchClaimAdoptionBonusPrize(1, 
                    Array.from({length: 300}, (_, i) => ({
                        cohortId: 4,
                        entrantId: i + 700
                    }))
                )).to.not.be.reverted;
                d = await ethers.provider.getBalance(game.target);
                let totalPaidTripleDigit = b-d;
                console.log(`Paid out for triple digit IDs: ${ethers.formatEther(totalPaidTripleDigit)} PLS`);
                expect(totalPaidSingleDigit).to.be.closeTo(totalPaidDoubleDigit, 10000000000000000000n);
                expect(totalPaidSingleDigit).to.be.closeTo(totalPaidTripleDigit, 10000000000000000000n);
                const totalPaid = totalPaidSingleDigit + totalPaidDoubleDigit + totalPaidTripleDigit;
                console.log(`Total paid out for cohort 4: ${ethers.formatEther(totalPaid)} PLS`);
                expect(totalPaid).to.be.closeTo(expectedPool3, 100000000000000000n);
                console.log("Testing invalid claims - should all fail");
                await expect(
                    game.batchClaimAdoptionBonusPrize(1, [{cohortId: 4, entrantId: 5}])
                ).to.be.reverted;
                await expect(
                    game.batchClaimAdoptionBonusPrize(1, [{cohortId: 4, entrantId: 100}])
                ).to.be.reverted;
                await expect(
                    game.batchClaimAdoptionBonusPrize(1, [{cohortId: 4, entrantId: 0}])
                ).to.be.reverted;
                await expect(
                    game.batchClaimAdoptionBonusPrize(1, [{cohortId: 4, entrantId: 15}])
                ).to.be.reverted;

            }
        }
        for(let i = 1; i < 50; i++) {
            
            await signers[i % 20].sendTransaction({
                to: game.target,
                value: 10n* BigInt(i)* ENTRY_AMOUNT // 10 entries per tx
            });
            
        }
 
        // Fast forward time
        console.log("Fast forwarding time past deadline");
        const deadline = await game.deadline();
        await ethers.provider.send("evm_increaseTime", [Number(deadline) + 10]);
        await ethers.provider.send("evm_mine");

        // Check that new entries revert after deadline
        console.log("Testing entry after deadline - should fail");
        await expect(
            signers[1].sendTransaction({
                to: game.target,
                value: ENTRY_AMOUNT
            })
        ).to.be.reverted;

        // Get total entrant count
        const totalEntrants = await game.entrantCount(1);
        const prizePerWinner = await game.prizePerWinner(1);
        console.log(`Total entrants: ${totalEntrants}`);
        console.log(`Prize per winner: ${ethers.formatEther(prizePerWinner)} PLS`);
        // Test winning IDs can claim
        const lastEntrantAddr = await game.entrants(1, totalEntrants);
        const balanceBefore = await ethers.provider.getBalance(lastEntrantAddr);
        console.log("Testing prize claim for last entrant");
        await expect(
            game.claimPrize(1, totalEntrants) // Last entrant
        ).to.not.be.reverted;
        const balanceAfter = await ethers.provider.getBalance(lastEntrantAddr);
        console.log(`Prize claimed: ${ethers.formatEther(balanceAfter - balanceBefore)} PLS`);
        expect(balanceAfter - balanceBefore).to.equal(prizePerWinner);

        // Try claiming again with same ID - should revert
        console.log("Testing double claim - should fail");
        await expect(
            game.claimPrize(1, totalEntrants)
        ).to.be.reverted;

        if (totalEntrants > 9) {
            console.log("Testing prize claim for winner at totalEntrants-9");
            const winnerAddr = await game.entrants(1, totalEntrants - 9n);
            const balanceBefore = await ethers.provider.getBalance(winnerAddr);
            await expect(
                game.claimPrize(1, totalEntrants - 9n) // Entrant count - 9
            ).to.not.be.reverted;
            const balanceAfter = await ethers.provider.getBalance(winnerAddr);
            console.log(`Prize claimed: ${ethers.formatEther(balanceAfter - balanceBefore)} PLS`);
            expect(balanceAfter - balanceBefore).to.equal(prizePerWinner);

            // Double claim attempt
            console.log("Testing double claim - should fail");
            await expect(
                game.claimPrize(1, totalEntrants - 9n)
            ).to.be.reverted;
        }

        if (totalEntrants > 99) {
            console.log("Testing prize claim for winner at totalEntrants-99");
            const winnerAddr = await game.entrants(1, totalEntrants - 99n);
            const balanceBefore = await ethers.provider.getBalance(winnerAddr);
            await expect(
                game.claimPrize(1, totalEntrants - 99n) // Entrant count - 99
            ).to.not.be.reverted;
            const balanceAfter = await ethers.provider.getBalance(winnerAddr);
            console.log(`Prize claimed: ${ethers.formatEther(balanceAfter - balanceBefore)} PLS`);
            expect(balanceAfter - balanceBefore).to.equal(prizePerWinner);

            // Double claim attempt
            console.log("Testing double claim - should fail");
            await expect(
                game.claimPrize(1, totalEntrants - 99n)
            ).to.be.reverted;
        }

        if (totalEntrants > 999) {
            const winnerAddr = await game.entrants(1, totalEntrants - 999n);
            const balanceBefore = await ethers.provider.getBalance(winnerAddr);
            await expect(
                game.claimPrize(1, totalEntrants - 999n) // Entrant count - 999
            ).to.not.be.reverted;
            const balanceAfter = await ethers.provider.getBalance(winnerAddr);
            expect(balanceAfter - balanceBefore).to.be.closeTo(prizePerWinner, 10000000000000000n);

            // Double claim attempt
            await expect(
                game.claimPrize(1, totalEntrants - 999n)
            ).to.be.reverted;
        }

        if (totalEntrants > 9999) {
            const winnerAddr = await game.entrants(1, totalEntrants - 9999n);
            const balanceBefore = await ethers.provider.getBalance(winnerAddr);
            await expect(
                game.claimPrize(1, totalEntrants - 9999n) // Entrant count - 9999
            ).to.not.be.reverted;
            const balanceAfter = await ethers.provider.getBalance(winnerAddr);
            expect(balanceAfter - balanceBefore).to.be.closeTo(prizePerWinner, 10000000000000000n);
            
            // Double claim attempt
            await expect(
                game.claimPrize(1, totalEntrants - 9999n)
            ).to.be.reverted;
        }

        // Test that non-winning IDs cannot claim
        await expect(
            game.claimPrize(1, totalEntrants - 1n)
        ).to.be.reverted;

        await expect(
            game.claimPrize(1, totalEntrants - 5n)
        ).to.be.reverted;

        if (totalEntrants > 50) {
            await expect(
                game.claimPrize(1, totalEntrants - 50n)
            ).to.be.reverted;
        }
        // Test clearLeftoverAdoptionBonus restrictions and functionality
        console.log("Testing clearLeftoverAdoptionBonus restrictions");

        // Get host address and balance before
        const hostAddr = await game.host();
        const hostBalanceBefore = await ethers.provider.getBalance(hostAddr);

        // Get cohort 5 adoption bonus pool amount
        const cohort5Pool = await game.adoptionBonusPrizePool(1, 5);
        // Calculate expected cohort 5 pool amount
        let f = await game.entrantCount(1);
        const numWinners = await game.getNumWinners(1);
        
        let ff = (10n ** BigInt(numWinners-1n));
      
        let stragglers = (f + 1n - ff)
        
        const expectedCohort5Pool =  stragglers * ENTRY_AMOUNT * 2n / 10n;
        expect(cohort5Pool).to.equal(expectedCohort5Pool);
        console.log(`Leftover Cohort 5 adoption bonus pool: ${ethers.formatEther(cohort5Pool)} PLS`);

        // Non-host should not be able to clear leftover
        await expect(
            game.connect(signers[1]).clearLeftoverAdoptionBonus(1)
        ).to.be.reverted;

        // Host should be able to clear leftover
        await expect(
            game.clearLeftoverAdoptionBonus(1)
        ).to.not.be.reverted;

        // Verify host received the correct amount
        const hostBalanceAfter = await ethers.provider.getBalance(hostAddr);
        const hostBalanceDiff = hostBalanceAfter - hostBalanceBefore;
        expect(hostBalanceDiff).to.be.closeTo(cohort5Pool, 1000000000000000n);
        console.log(`Cleaned Up ${ethers.formatEther(hostBalanceDiff)} leftover PLS`);

        // Should not be able to clear twice
        await expect(
            game.clearLeftoverAdoptionBonus(1)
        ).to.be.reverted;

        // Test that cohorts 1-4 cannot claim from cohort 5
        console.log("Testing invalid claims from cohort 5");
        await expect(
            game.batchClaimAdoptionBonusPrize(1, [{cohortId: 5, entrantId: 1}])
        ).to.be.reverted;

        await expect(
            game.batchClaimAdoptionBonusPrize(1, [{cohortId: 5, entrantId: 15}])
        ).to.be.reverted;

        await expect(
            game.batchClaimAdoptionBonusPrize(1, [{cohortId: 5, entrantId: 99}])
        ).to.be.reverted;

        await expect(
            game.batchClaimAdoptionBonusPrize(1, [{cohortId: 5, entrantId: 999}])
        ).to.be.reverted;
    
    });
    });
});