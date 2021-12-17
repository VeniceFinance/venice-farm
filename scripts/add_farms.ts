import { network, ethers } from 'hardhat';
import { Contract, ContractFactory, BigNumber, utils } from 'ethers';
import { encodeParameters, wait } from './utils';
const { MASTERCHEF, FARMS, PAIRS } = require('./config');

async function main() {
    const { provider } = ethers;
    const [ operator ] = await ethers.getSigners();

    const estimateGasPrice = await provider.getGasPrice();
    const gasPrice = estimateGasPrice.mul(3).div(2);
    console.log(`Gas Price: ${ethers.utils.formatUnits(gasPrice, 'gwei')} gwei`);
    const override = { gasPrice };

    console.log(`====================Do your bussiness =======================`)
    
    const masterChef = await ethers.getContractAt('MasterChef', MASTERCHEF);
    for (var farm of FARMS) {
        let tx = await masterChef.add(
            farm.allocPoint,
            PAIRS[farm.lpToken][network.name],
            farm.withUpdate,
        );
        await wait(ethers, tx.hash, 
            `Farms => ${farm.lpToken}`
        );
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });