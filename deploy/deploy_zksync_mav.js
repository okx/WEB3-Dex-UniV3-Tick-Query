const { Provider, Wallet, Contract, utils } = require("zksync-web3");
const { Deployer } = require("@matterlabs/hardhat-zksync-deploy");
// load env file
require('dotenv').config();

// load wallet private key from env file
const PRIVATE_KEY = process.env.PRIVATE_KEY || "";

if (!PRIVATE_KEY) throw "⛔️ Private key not detected! Add it to the .env file!";

// yarn hardhat deploy-zksync --script deploy_zksync.js
const deploy = async function (hre) {
    console.log(`Running deploy script for the Quoter contract`);

    // Initialize the wallet.
    const wallet = new Wallet(PRIVATE_KEY);

    // Create deployer object and load the artifact of the contract you want to deploy.
    const deployer = new Deployer(hre, wallet);
    const artifact = await deployer.loadArtifact("MavrickQuoter");


    const greeterContract = await deployer.deploy(artifact);


    // Show the contract info.
    const contractAddress = greeterContract.address;
    console.log(`${artifact.contractName} was deployed to ${contractAddress}`);
}
module.exports = deploy