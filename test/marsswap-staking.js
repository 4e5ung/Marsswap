const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");
const { Bignumber } = require("ethers");

describe("Mars, staking", function () {

    let accounts;
    let MarsswapFactoryContract;
    let mockToken0Contract;
    let mockToken1Contract;
    let WMATICContract;
    let routerContract;
    let MarsswapStakingFactoryContract;
    let mockRewardTokenContract;

    const MaxUint256 = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

    const overrides = {
        gasLimit: 9999999
    }

    beforeEach(async function () { 
        accounts = await ethers.getSigners();

        MarsswapFactoryContract = await (await ethers.getContractFactory("MarsswapFactory")).deploy(accounts[0].address);
        MarsswapStakingFactoryContract = await (await ethers.getContractFactory("MarsswapStakingFactory")).deploy();
        
        const MockTokenContract = await ethers.getContractFactory("TokenERC20");
        mockToken0Contract = await MockTokenContract.deploy("TestToken", "CVTX");
        mockToken1Contract = await MockTokenContract.deploy("TestToken", "MTIX");
        mockRewardTokenContract = await MockTokenContract.deploy("TestToken", "YS");


        WMATICContract = await (await ethers.getContractFactory("MarsswapMatic")).deploy();

        const swapFee = 30;
        const protocolFee = 5;
        await MarsswapFactoryContract.createPair(mockToken0Contract.address, mockToken1Contract.address, swapFee, protocolFee);
        await MarsswapFactoryContract.createPair(mockToken0Contract.address, WMATICContract.address, swapFee, protocolFee);

        routerContract = await (await ethers.getContractFactory("MarsswapRouter")).deploy(MarsswapFactoryContract.address, WMATICContract.address);

        await mockToken0Contract.approve(accounts[0].address, MaxUint256);
        await mockToken0Contract.transferFrom(accounts[0].address, accounts[1].address, ethers.utils.parseEther("100.0"));
        
        await mockToken1Contract.approve(accounts[0].address, MaxUint256);
        await mockToken1Contract.transferFrom(accounts[0].address, accounts[1].address, ethers.utils.parseEther("100.0"));
    });
    

    it("Staking test", async function(){
        
        /* LP 등록 */
        await mockToken0Contract.approve(routerContract.address, MaxUint256)
        await mockToken1Contract.approve(routerContract.address, MaxUint256)
       
        await routerContract.connect(accounts[0]).addLiquidity(
            mockToken0Contract.address,
            mockToken1Contract.address,
            ethers.utils.parseEther("10.0"),
            ethers.utils.parseEther("5.0"),
            0,
            0,
            accounts[0].address,
            MaxUint256,
            overrides
        )

        //  7071067811865475144

        await mockToken0Contract.connect(accounts[1]).approve(routerContract.address, MaxUint256)
        await mockToken1Contract.connect(accounts[1]).approve(routerContract.address, MaxUint256)
        
        await routerContract.connect(accounts[1]).addLiquidity(
            mockToken0Contract.address,
            mockToken1Contract.address,
            ethers.utils.parseEther("0.005"),
            ethers.utils.parseEther("0.0025"),
            0,
            0,
            accounts[1].address,
            MaxUint256,
            overrides
        )
        
        //  3535533905932737

        ////////////////////////////////////////////////////////////

        pair = await MarsswapFactoryContract.getPair(mockToken0Contract.address, mockToken1Contract.address);
        pairContract = (await ethers.getContractFactory("MarsswapPair")).attach(pair);


        balance = await pairContract.balanceOf(accounts[0].address);
        // console.log("balance: ", data );


        const rewardPerSecond = 10000; //uint256
        const startTimestamp = parseInt(new Date().getTime() / 1000) //uint256
        // const bonusPeriodInSeconds = 2419200
        const bonusPeriodInSeconds = 43200*30;
        const bonusEndTimestamp = startTimestamp + bonusPeriodInSeconds; //uint256
        // const poolLimitPerUser = 100000000000; //uint256
        const poolLimitPerUser = 0; //uint256

        await MarsswapStakingFactoryContract.deployPool( 
            pairContract.address, 
            mockRewardTokenContract.address,
            rewardPerSecond,
            startTimestamp,
            bonusEndTimestamp,
            poolLimitPerUser,
            accounts[0].address,
            overrides
            );
        
        
        pool = await MarsswapStakingFactoryContract.getPool(pairContract.address);
        poolContract = (await ethers.getContractFactory("MarsswapStakingPool")).attach(pool);

        await mockRewardTokenContract.approve(accounts[0].address, MaxUint256);
        await mockRewardTokenContract.transferFrom(accounts[0].address, poolContract.address, ethers.utils.parseEther("10.0"));

        // 스테이킹
        await pairContract.connect(accounts[0]).approve(poolContract.address, MaxUint256);
        await poolContract.connect(accounts[0]).deposit(3535533905932737n, accounts[0].address);  


        // 스테이킹 해제
        await mockRewardTokenContract.connect(accounts[0]).approve(poolContract.address, MaxUint256);
        await poolContract.connect(accounts[0]).withdraw(3535533905932737n, accounts[0].address);

        
        // 트렉젝션을 강제 발생 
        await pairContract.connect(accounts[0]).approve(poolContract.address, MaxUint256);
        reward = await poolContract.userState(accounts[0].address);
        // console.log("reward: ", reward);
    });
});
