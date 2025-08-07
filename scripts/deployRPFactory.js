const hre = require("hardhat");

async function main() {
    const RPFactory = await hre.ethers.getContractFactory("RPFactory");
    const factory = await RPFactory.deploy();
    await factory.waitForDeployment();

    console.log("RPfactory deployed to:", await factory.getAddress());
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
