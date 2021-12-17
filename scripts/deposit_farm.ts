import { network, ethers } from 'hardhat';
import { Contract, ContractFactory, BigNumber, utils } from 'ethers';
import { encodeParameters, wait } from './utils';
const { MASTERCHEF, PAIRS } = require('./config');

async function main() {
    const { provider } = ethers;
    const [ operator ] = await ethers.getSigners();

    const estimateGasPrice = await provider.getGasPrice();
    const gasPrice = estimateGasPrice.mul(3).div(2);
    console.log(`Gas Price: ${ethers.utils.formatUnits(gasPrice, 'gwei')} gwei`);
    const override = { gasPrice };

    console.log(`====================Do your bussiness =======================`)

    // approve pair token to MasterChef
    let pairToken = await ethers.getContractAt('IERC20', PAIRS['DOT-WFRA'][network.name]);
    let pairUnit = ethers.utils.parseUnits('2', 18);
    let tx1 = await pairToken.approve(MASTERCHEF, pairUnit);
    await wait(ethers, tx1.hash, '1# approve pair token to MasterChef');
    // deposit
    const masterChef = await ethers.getContractAt('MasterChef', MASTERCHEF);
    let tx2 = await masterChef.deposit(0, pairUnit);
    await wait(ethers, tx2.hash, 'pair deposit');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });