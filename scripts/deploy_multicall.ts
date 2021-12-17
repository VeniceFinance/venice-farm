import { network, ethers } from 'hardhat';
import { Contract, ContractFactory, BigNumber, utils } from 'ethers';
import { encodeParameters, wait } from './utils';
const { MASTERCHEF } = require('./config');

async function main() {
    const { provider } = ethers;
    const [ operator ] = await ethers.getSigners();

    const estimateGasPrice = await provider.getGasPrice();
    const gasPrice = estimateGasPrice.mul(3).div(2);
    console.log(`Gas Price: ${ethers.utils.formatUnits(gasPrice, 'gwei')} gwei`);
    const override = { gasPrice };

    console.log(`====================Do your bussiness =======================`)

    const Multicall = await ethers.getContractFactory("Multicall");
    console.log("Deploying Multicall...");
    let multicall = await Multicall.deploy();
    await multicall.deployed();
    console.log("Multicall Address is: ", multicall.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });