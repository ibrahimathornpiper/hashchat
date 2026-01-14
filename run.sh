#!/bin/bash

# ==========================================
# CONTEXT7 AUTO-DEPLOY SCRIPT (DEBUGGED)
# TARGET: Debian 11/12
# STACK: Node.js, Hardhat, Flutter, Nginx
# ==========================================

set -e

# Hardcoded Config
IP="34.16.22.173"
NETWORK="Polygon Amoy"
export RPC_URL="https://rpc-amoy.polygon.technology/"
PROJECT_DIR=$(pwd)
export DEBIAN_FRONTEND=noninteractive

echo ">>> [1/6] SYSTEM SETUP & SWAP..."
# Swap 4GB
if ! grep -q "swapfile" /etc/fstab; then
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
fi

# Install dependencies (Removed npm from list as nodejs includes it)
apt-get update && apt-get install -y curl git nginx nodejs unzip xz-utils
npm install -g pm2

echo ">>> [2/6] WALLET GENERATION & FUNDING..."
# Do not remove wallet_gen if it exists to save funds during re-runs
mkdir -p wallet_gen
cd wallet_gen
if [ ! -f "package.json" ]; then
    npm init -y > /dev/null
    npm install ethers@6 dotenv > /dev/null
fi

# Use quoted heredoc to prevent expansion
cat <<'EOF' > gen_wallet.js
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
EOF

# Run with exported RPC_URL
export RPC_URL_FROM_ENV=$RPC_URL
node gen_wallet.js

# Load Env into Bash - explicit cat and xargs
export $(cat .env | xargs)
cd ..

echo ">>> [3/6] PHASE 1: SMART CONTRACT (Hardhat Raw Compile & Deploy)..."
rm -rf smart_contract
mkdir -p smart_contract
cd smart_contract
npm init -y > /dev/null
# Set type to module for ESM
npm pkg set type="module"
# Install specific older Hardhat version
npm install --save-dev hardhat@2.19.0 ethers@6 dotenv --legacy-peer-deps > /dev/null

# Hardhat Config (Minimal for Compile Only)
cat <<'EOF' > hardhat.config.js
export default {
  solidity: "0.8.19"
};
EOF

mkdir -p contracts scripts

# Smart Contract
cat <<'EOF' > contracts/BurnerChat.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract BurnerChat {
    event NewMessage(address indexed sender, string message, uint256 timestamp);

    function sendMessage(string memory _message) public {
        emit NewMessage(msg.sender, _message, block.timestamp);
    }
}
EOF

# Deploy Script (Raw Ethers)
cat <<'EOF' > scripts/deploy_raw.js
import { ethers } from "ethers";
import fs from "fs";
import path from "path";
import { fileURLToPath } from 'url';
import dotenv from "dotenv";

dotenv.config({ path: "../wallet_gen/.env" });

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function main() {
  const { RPC_URL, PRIVATE_KEY } = process.env;
  if (!RPC_URL || !PRIVATE_KEY) throw new Error("Missing Env Config");

  console.log("Connecting to:", RPC_URL);
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

  // Load Artifact
  const artifactPath = path.join(__dirname, "../artifacts/contracts/BurnerChat.sol/BurnerChat.json");
  if (!fs.existsSync(artifactPath)) throw new Error("Artifact not found. Did you compile?");
  
  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
  
  console.log("Deploying contract...");
  const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, wallet);
  const contract = await factory.deploy();
  
  console.log("Waiting for deployment...");
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  
  console.log("Contract Deployed to:", address);
  fs.writeFileSync(path.join(__dirname, "../../address.txt"), address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOF

# Compile
npx hardhat compile

# Run Deploy
node scripts/deploy_raw.js
CONTRACT_ADDRESS=$(cat ../address.txt)
cd ..

echo ">>> [4/6] PHASE 2: BACKEND (Relayer)..."
rm -rf server
mkdir -p server
cd server
npm init -y > /dev/null
npm install express ethers@6 cors dotenv --legacy-peer-deps > /dev/null

cat <<'EOF' > server.js
const express = require('express');
const { ethers } = require('ethers');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
// Override to ensure we load the file even if env is polluted
require('dotenv').config({ path: '../wallet_gen/.env', override: true });

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

    if (rateLimit.has(userAddress)) {
        return res.status(429).send('Already claimed');
    }

    try {
        const tx = await wallet.sendTransaction({
            to: userAddress,
            value: ethers.parseEther("0.05")
        });
        rateLimit.set(userAddress, true);
        res.json({ success: true, txHash: tx.hash });
    } catch (e) {
        console.error(e);
        res.status(500).json({ error: 'Transaction failed' });
    }
});

app.listen(3000, () => console.log('Relayer running on port 3000'));
EOF

# Idempotent PM2 start (delete all to be safe)
pm2 delete all 2>/dev/null || true
pm2 start server.js --name api
cd ..

echo ">>> [5/6] PHASE 3: FRONTEND (Flutter Web)..."
if [ ! -d "flutter" ]; then
    git clone https://github.com/flutter/flutter.git -b stable
fi
export PATH="$PROJECT_DIR/flutter/bin:$PATH"

# Pre-download artifacts
flutter precache

# Create Project
rm -rf client
flutter create client
cd client

# Add deps
sed -i 's/dependencies:/dependencies:\n  http: ^1.1.0\n  web3dart: ^2.7.0\n  shared_preferences: ^2.2.0/' pubspec.yaml
flutter pub get

# Main.dart
cat <<'EOF' > lib/main.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BurnerChat',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFE0E5EC), // Neumorphic bg
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isHealthOk = false;
  String statusText = "Checking System...";
  TextEditingController searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkHealth();
  }

  Future<void> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('/api/health')); 
      if (response.statusCode == 200) {
        setState(() {
          isHealthOk = true;
          statusText = "System Online";
        });
      }
    } catch (e) {
      setState(() {
        statusText = "Offline";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFE0E5EC).withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.5),
                offset: const Offset(-6, -6),
                blurRadius: 16,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(6, 6),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("BurnerChat", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isHealthOk ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isHealthOk ? Colors.green.withOpacity(0.6) : Colors.red.withOpacity(0.6),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText: "0x... Search User Address",
                  filled: true,
                  fillColor: Colors.white54,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text("Connect & Chat"),
              ),
              const SizedBox(height: 10),
              Text(statusText, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
EOF

# Build Web (No flags for renderer, standard build)
flutter build web --release
cd ..

echo ">>> [6/6] DEPLOY (Nginx)..."
rm -rf /var/www/html/*
cp -r client/build/web/* /var/www/html/

# Nginx Config (Using quoted heredoc, so $variables are NOT expanded by bash)
cat <<'EOF' > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm;

    server_name _;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

systemctl restart nginx

echo "=========================================="
echo "DEPLOYMENT COMPLETE!"
echo "URL: http://$IP"
echo "CONTRACT: $CONTRACT_ADDRESS"
echo "==========================================