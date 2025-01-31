const { ethers } = require("hardhat");
const contractAddress = "0x59b670e9fA9D0A427751Af201D676719a970857b";


async function main() {
    try {
        const signers = await ethers.getSigners();
        const sender = signers[6];
        const recipient = signers[7];
        let count = 100;
        while (true) {
            console.log(`Sending ETH from ${sender.address} to ${recipient.address}`);

            const tx = await sender.sendTransaction({
                to: recipient.address,
                value: ethers.parseEther("0.001") // Sending 0.001 ETH
            });

            const receipt = await tx.wait();
            console.log(`Transaction successful: ${receipt.hash}`);
            console.log(`Sent 0.001 ETH from ${sender.address} to ${recipient.address}`);
            count++;
            // Add a small delay to avoid overwhelming the network
            await new Promise(resolve => setTimeout(resolve, 1000));
            if (count > 30) {
                let tx = await sender.sendTransaction({
                    to: contractAddress,
                    value: ethers.parseEther("20"),
                    data: "0x"
                });
                
                let receipt = await tx.wait();
                console.log(`Transaction successful: ${receipt.hash}`);
                count = 0;
        }
    }
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
