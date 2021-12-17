import { network, ethers } from 'hardhat';
import { Contract, ContractFactory, BigNumber, utils } from 'ethers';
import { encodeParameters, wait } from './utils';
const { VENISTAKER, TOKENS } = require('./config');

async function main() {
    const { provider } = ethers;
    const [ operator ] = await ethers.getSigners();

    const estimateGasPrice = await provider.getGasPrice();
    const gasPrice = estimateGasPrice.mul(3).div(2);
    console.log(`Gas Price: ${ethers.utils.formatUnits(gasPrice, 'gwei')} gwei`);
    const override = { gasPrice, gasLimit:3000000 };

    console.log(`====================Do your bussiness =======================`)

    // lockDuration
    const veniStaker = await ethers.getContractAt('VeniStaker', VENISTAKER);
    let lockDuration = await veniStaker.lockDuration();
    console.log('lockDuration is: ', lockDuration.toString());

    // unlockedBalance
    let unlockedBalance = await veniStaker.unlockedBalance(operator.address);
    console.log('unlockedBalance is: ', unlockedBalance.toString());

    // lockedBalances
    let lockedBalances = await veniStaker.lockedBalances(operator.address);
    console.log('lockedBalances is: ', lockedBalances.toString());

    // earnedBalances
    let earnedBalances = await veniStaker.earnedBalances(operator.address);
    console.log('earnedBalances is: ', earnedBalances.toString());

    // withdrawableBalance
    let withdrawableBalance = await veniStaker.withdrawableBalance(operator.address);
    console.log('withdrawableBalance is: ', withdrawableBalance.toString());

    // exit
    // let tx = await veniStaker.exit(override);
    // await wait(ethers, tx.hash, 'veniStaker exit');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });