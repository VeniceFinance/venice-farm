const MULTICALL = '0xA62AF8b29caA923B4dd0F39f3645c7279f413701'
const MASTERCHEF = '0x8315672444e6245abF153633c76d01c01e8E4a7e'
const VENISTAKER =  '0x825FEE0fdb11B2874aA6F9D2b1663c3FD4d36908'
const REWARDSPERSECOND = '1000000000000000000'
const STARTTIME =  1638374400

const FARMS = [
    {lpToken:'DOT-WFRA', allocPoint:'500', withUpdate:false},
    // {lpToken:'LTC-WFRA', allocPoint:'600', withUpdate:false},
    // {lpToken:'DOGE-WFRA', allocPoint:'700', withUpdate:false},
    // {lpToken:'BUSD-WFRA', allocPoint:'800', withUpdate:false},
    // {lpToken:'VENI-WFRA', allocPoint:'400', withUpdate:false},
]

const POOLS = [
    {
        stakedToken: 'VENI', rewardToken: 'USDT', rewardPerBlock: '100000000000000000', 
        startBlock: 325000, bonusEndBlock: 335000, poolLimitPerUser: 0
    },
]

const TOKENS = {
    'WFRA': {
        'test': '0x27f9AcDBf683903646e1Ea36187f845493278Ab3'
    },
    'USDT': {
        'test': '0x287859aBcDb70A9cA96b39A985F8c26e1369f27e'
    },
    'BUSD': {
        'test': '0xDc4c479d104E63619c28326C5616F52858FC888D'
    },
    'BTCB': {
        'test': '0xaD99fB7B3Dc08A9c4091011053E6572c42418BfF'
    },
    'BETH': {
        'test': '0xB3707148Ea11212576d713a840D0ca1cF564DA5c'
    },
    'USDC': {
        'test': '0x5C8d4E325779f8b9B37E55FC5bCE5488624734c2'
    },
    'DAI': {
        'test': '0x9ff098e601E4a02F272EC12913Ef93E71a3Fe8E4'
    },
    'CAKE': {
        'test': '0x56a110Daa46Bcf94B560ade3c83bb29C8ed4E881'
    },
    'DOT': {
        'test': '0x66Bee82Be0f5d88B51109e15522a87B265edd457'
    },
    'LTC': {
        'test': '0x835C3C004c187DBa43185FCb47d73CAB72cb82E2'
    },
    'DOGE': {
        'test': '0xa46125DC6238CAF1b4A0737204FFb25eD0aDB104'
    },
    'VENI': {
        'test': '0xffceA0c39e47b565B794E1D74965d59b9D976a85'
    }
}

const PAIRS = {
    'USDT-BUSD': {
        'test': '0x72Fb512ACa9317e661d3771a311aFc74BB599c57'
    },
    'USDT-WFRA': {
        'test': '0xB416aD90BD04a1070BD8fEaEA4365dbDc9a5DE75'
    },
    'BUSD-WFRA': {
        'test': '0xeAb5137855Bc67d33f56865940a435Ca70bCD298'
    },
    'DAI-WFRA': {
        'test': '0x10f30d251c158105fA0B9CACd2db51D235A9EcD5'
    },
    'DOT-WFRA': {
        'test': '0x36035D312D6eCFD3EF84313AAF57De2288F63d4D'
    },
    'LTC-WFRA': {
        'test': '0x7E4eA6869D454CDF1772378d82ad387eE13efa79'
    },
    'DOGE-WFRA': {
        'test': '0x923dD0a6b8002C25fb1441bdc3C3f369735d47FF'
    },
    'VENI-WFRA': {
        'test': '0x8088Da1D83f59f09c6b996CcDC6eA0503e1986F4'
    }
}

const SMARTCHEF = {
    'USDT':{
        'test': '0xA95A87aF940C6d1681126150A024A464711E4d27'
    }
}

module.exports = {
    MULTICALL,
    MASTERCHEF,
    VENISTAKER,
    SMARTCHEF,
    REWARDSPERSECOND,
    STARTTIME,
    TOKENS,
    PAIRS,
    FARMS,
    POOLS
}