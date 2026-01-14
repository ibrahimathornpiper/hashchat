const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

async function main() {
    const rpcUrl = process.env.RPC_URL || process.env.RPC_URL_FROM_ENV; 
    
    // Check if we need to generate or reuse
    let wallet;
    let envPath = path.join(__dirname, ".env");
    
    if (process.env.PRIVATE_KEY && process.env.ADDRESS) {
        console.log("Found existing wallet configuration.");
        wallet = new ethers.Wallet(process.env.PRIVATE_KEY);
    } else {
        if (!rpcUrl) throw new Error("RPC_URL not set");
        const provider = new ethers.JsonRpcProvider(rpcUrl);
        wallet = ethers.Wallet.createRandom();
        
        const envContent = "PRIVATE_KEY=" + wallet.privateKey + "\n" +
                           "ADDRESS=" + wallet.address + "\n" +
                           "RPC_URL=" + rpcUrl;
                           
        fs.writeFileSync(envPath, envContent);
        console.log("Generated NEW wallet.");
    }
    
    // Reload env to ensure we have everything
    require("dotenv").config();
    const finalRpc = process.env.RPC_URL || rpcUrl;
    const provider = new ethers.JsonRpcProvider(finalRpc);
    const connectedWallet = wallet.connect(provider);

    console.log("------------------------------------------------");
    console.log("WALLET ADDRESS: " + wallet.address);
    console.log("WAITING FOR FUNDS... SEND 0.5 MATIC TO THIS ADDRESS.");
    console.log("------------------------------------------------");

    while (true) {
        try {
            const balance = await provider.getBalance(wallet.address);
            const balanceEth = ethers.formatEther(balance);
            process.stdout.write("\rCurrent Balance: " + balanceEth + " MATIC");
            
            if (parseFloat(balanceEth) > 0.1) {
                console.log("\n\n>>> FUNDS RECEIVED! Starting deployment...");
                break;
            }
        } catch (e) {
            console.error(e);
        }
        await new Promise(r => setTimeout(r, 3000));
    }
}

main();
