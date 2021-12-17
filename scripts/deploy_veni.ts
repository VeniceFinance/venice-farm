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

    const Venice = await ethers.getContractFactory("Venice");
    console.log("Deploying Venice...");
    let venice = await Venice.deploy();
    await venice.deployed();
    console.log("Venice Address is: ", venice.address);
    // add minter
    let tx1 = await venice.addMinter(operator.address);
    await wait(ethers, tx1.hash, 'Venice addMinter');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });