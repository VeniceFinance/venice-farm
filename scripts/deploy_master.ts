import { network, ethers } from 'hardhat';
import { Contract, ContractFactory, BigNumber, utils } from 'ethers';
import { encodeParameters, wait } from './utils';
const { REWARDSPERSECOND, STARTTIME, VENISTAKER} = require('./config');

async function main() {
    const { provider } = ethers;
    const [ operator ] = await ethers.getSigners();

    const estimateGasPrice = await provider.getGasPrice();
    const gasPrice = estimateGasPrice.mul(3).div(2);
    console.log(`Gas Price: ${ethers.utils.formatUnits(gasPrice, 'gwei')} gwei`);
    const override = { gasPrice };

    console.log(`====================Do your bussiness =======================`)
    
    const MasterChef = await ethers.getContractFactory("MasterChef");
    console.log("Deploying MasterChef...");
    let masterChef = await MasterChef.deploy(
        REWARDSPERSECOND,
        STARTTIME,
        VENISTAKER
    );
    await masterChef.deployed();
    console.log("MasterChef Address is: ", masterChef.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });