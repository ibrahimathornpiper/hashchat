const express = require('express');
const { ethers } = require('ethers');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
// Override to ensure we load the file even if env is polluted
require('dotenv').config({ path: path.resolve(__dirname, '../wallet_gen/.env'), override: true });

const app = express();
app.use(cors());
app.use(express.json());

const CONTRACT_ADDRESS = fs.readFileSync(path.join(__dirname, '../address.txt'), 'utf8').trim();

const pKey = process.env.PRIVATE_KEY;
if (!pKey) {
    console.error("FATAL: PRIVATE_KEY is missing.");
    process.exit(1);
}
console.log("Loaded Key Length:", pKey.length);

const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(pKey, provider);

// Rate limiting map (simple in-memory)
const rateLimit = new Map();

app.get('/health', async (req, res) => {
    try {
        const balance = await provider.getBalance(wallet.address);
        res.json({
            status: 'ok',
            contract: CONTRACT_ADDRESS,
            relayerBalance: ethers.formatEther(balance)
        });
    } catch (e) {
        res.status(500).json({ status: 'error', error: e.message });
    }
});

app.post('/claim', async (req, res) => {
    const userAddress = req.body.address;
    if (!userAddress || !ethers.isAddress(userAddress)) {
        return res.status(400).send('Invalid address');
    }

    // Check if user has enough balance (prevent draining)
    try {
        const currentBalance = await provider.getBalance(userAddress);
        const threshold = ethers.parseEther("0.05"); 
        
        if (currentBalance > threshold) {
            return res.status(400).json({ error: 'Balance is sufficient. No top-up needed.' });
        }

        // Simple cooldown check
        const lastClaim = rateLimit.get(userAddress) || 0;
        const now = Date.now();
        if (now - lastClaim < 60000) { // 1 minute cooldown
            return res.status(429).json({ error: 'Please wait a moment before claiming again.' });
        }

        const tx = await wallet.sendTransaction({
            to: userAddress,
            value: ethers.parseEther("0.1")
        });
        
        rateLimit.set(userAddress, now);
        res.json({ success: true, txHash: tx.hash });
    } catch (e) {
        console.error(e);
        res.status(500).json({ error: 'Transaction failed', details: e.message });
    }
});

app.listen(3000, () => console.log('Relayer running on port 3000'));
