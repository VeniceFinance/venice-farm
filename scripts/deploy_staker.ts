import { network, ethers } from 'hardhat';
import { Contract, ContractFactory, BigNumber, utils } from 'ethers';
import { encodeParameters, wait } from './utils';
const { TOKENS } = require('./config');

async function main() {
    const { provider } = ethers;
    const [ operator ] = await ethers.getSigners();

    const estimateGasPrice = await provider.getGasPrice();
    const gasPrice = estimateGasPrice.mul(3).div(2);
    console.log(`Gas Price: ${ethers.utils.formatUnits(gasPrice, 'gwei')} gwei`);
    const override = { gasPrice };

    console.log(`====================Do your bussiness =======================`)
    
    const VeniStaker = await ethers.getContractFactory("VeniStaker");
    console.log("Deploying VeniStaker...");
    let veniStaker = await VeniStaker.deploy(
        TOKENS['VENI'][network.name]
    );
    await veniStaker.deployed();
    console.log("VeniStaker Address is: ", veniStaker.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });