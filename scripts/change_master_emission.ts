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

    // unlockedBalance
    const masterChef = await ethers.getContractAt('MasterChef', MASTERCHEF);

    let second = await masterChef.rewardsPerSecond();
    console.log('second is:', second.toString());

    // let tx = await masterChef.setSchedule(
    //     [82800],
    //     ['300000000000000000']
    // );
    // await wait(ethers, tx.hash, 'MasterChef setSchedule');

    let tx1 = await masterChef.updatePool(0);
    await wait(ethers, tx1.hash, 'MasterChef updatePool');

    second = await masterChef.rewardsPerSecond();
    console.log('second is:', second.toString());
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });