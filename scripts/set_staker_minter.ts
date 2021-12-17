import { network, ethers } from 'hardhat';
import { Contract, ContractFactory, BigNumber, utils } from 'ethers';
import { encodeParameters, wait } from './utils';
const { VENISTAKER, MASTERCHEF } = require('./config');

async function main() {
    const { provider } = ethers;
    const [operator] = await ethers.getSigners();

    const estimateGasPrice = await provider.getGasPrice();
    const gasPrice = estimateGasPrice.mul(3).div(2);
    console.log(`Gas Price: ${ethers.utils.formatUnits(gasPrice, 'gwei')} gwei`);
    const override = { gasPrice };

    console.log(`====================Do your bussiness =======================`)

    let veniStaker = await ethers.getContractAt('VeniStaker', VENISTAKER);
    let tx1 = await veniStaker.setMinter([MASTERCHEF]);
    await wait(ethers, tx1.hash, 'VeniStaker addMinter');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });