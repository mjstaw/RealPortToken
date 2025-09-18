const { ethers } = require("hardhat");

async function main() {
  // 👇 Replace with the correct USDT address for your network
  const USDT_ADDRESS = "0xA40d4dD39114178E193Bbd38C1F48271D0b2B707";

  console.log("Deploying RPMarket...");
  const RPMarket = await ethers.getContractFactory("RPMarket");
const market = await RPMarket.deploy(USDT_ADDRESS); // Already deployed after await
console.log(`✅ RPMarket deployed at: ${market.target}`);

}

main().catch((error) => {
  console.error("❌ Deployment failed:", error);
  process.exitCode = 1;
});
