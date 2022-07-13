const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");

describe("Mars, farming", function () {

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

        const factory = await ethers.getContractFactory("MarsswapFactory");
        MarsswapFactoryContract = await factory.deploy(accounts[0].address);

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

        const routerFactory = await ethers.getContractFactory("MarsswapRouter");
        routerContract = await routerFactory.deploy(MarsswapFactoryContract.address, WMATICContract.address);

        await mockToken0Contract.approve(accounts[0].address, MaxUint256);
        await mockToken0Contract.transferFrom(accounts[0].address, accounts[1].address, ethers.utils.parseEther("100.0"));
        
        await mockToken1Contract.approve(accounts[0].address, MaxUint256);
        await mockToken1Contract.transferFrom(accounts[0].address, accounts[1].address, ethers.utils.parseEther("100.0"));
    });

  
    it("Farming Token", async function(){
        
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

        // await mockToken0Contract.connect(accounts[1]).approve(routerContract.address, MaxUint256)
        // await mockToken1Contract.connect(accounts[1]).approve(routerContract.address, MaxUint256)
        
        // await routerContract.connect(accounts[1]).addLiquidity(
        //     mockToken0Contract.address,
        //     mockToken1Contract.address,
        //     ethers.utils.parseEther("0.005"),
        //     ethers.utils.parseEther("0.0025"),
        //     0,
        //     0,
        //     accounts[1].address,
        //     MaxUint256,
        //     overrides
        // )
        
        //  3535533905932737

        ////////////////////////////////////////////////////////////

        pair = await MarsswapFactoryContract.getPair(mockToken0Contract.address, mockToken1Contract.address);
        pairContract = (await ethers.getContractFactory("MarsswapPair")).attach(pair);


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


        farmingContract = await (await ethers.getContractFactory("MarsswapFarming")).deploy(
            routerContract.address,
            MarsswapStakingFactoryContract.address,
            accounts[0].address);


        await mockToken0Contract.connect(accounts[1]).approve(farmingContract.address, MaxUint256)
        await mockToken1Contract.connect(accounts[1]).approve(farmingContract.address, MaxUint256)
        await pairContract.connect(accounts[1]).approve(poolContract.address, MaxUint256)
        await farmingContract.connect(accounts[1]).invest(
            mockToken0Contract.address, 
            mockToken1Contract.address, 
            5000, 
            5000, 
            0, 
            0);


        // data = await mockRewardTokenContract.balanceOf(accounts[1].address);
        // console.log("balanceOf: ", data);

        await pairContract.connect(accounts[1]).approve(poolContract.address, MaxUint256);
        data = await farmingContract.userInfo(mockToken0Contract.address, mockToken1Contract.address, accounts[1].address);
        console.log("userInfo: ", data);


        // await pairContract.connect(accounts[1]).approve(routerContract.address, MaxUint256);
        // await farmingContract.connect(accounts[1]).withdraw(
        //     mockToken0Contract.address,
        //     mockToken1Contract.address, 
        //     300, 
        //     0,
        //     0);

        // await pairContract.connect(accounts[1]).approve(poolContract.address, MaxUint256);
        // data = await farmingContract.userInfo(mockToken0Contract.address, mockToken1Contract.address, accounts[1].address);
        // console.log("data: ", data);


        // data = await mockRewardTokenContract.balanceOf(accounts[1].address);
        // console.log("balanceOf: ", data);

        // await farmingContract.connect(accounts[1]).harvest(mockToken0Contract.address, mockToken1Contract.address);


        // data = await mockRewardTokenContract.balanceOf(accounts[1].address);
        // console.log("balanceOf: ", data);
    });

    it("Farming Coin", async function(){
        
        /* LP 등록 */
        await mockToken0Contract.approve(routerContract.address, MaxUint256)

        const overridesLP = {
            gasLimit: 9999999,
            value : ethers.utils.parseEther("50.0")
        }

        await routerContract.connect(accounts[0]).addLiquidityETH(
            mockToken0Contract.address,
            ethers.utils.parseEther("1.0"),
            0,
            0,
            accounts[0].address,
            MaxUint256,
            overridesLP
        )
        ////////////////////////////////////////////////////////////

        pair = await MarsswapFactoryContract.getPair(mockToken0Contract.address, WMATICContract.address);
        pairContract = (await ethers.getContractFactory("MarsswapPair")).attach(pair);


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


        farmingContract = await (await ethers.getContractFactory("MarsswapFarming")).deploy(
            routerContract.address,
            MarsswapStakingFactoryContract.address,
            accounts[0].address);


        const overridesFM = {
            gasLimit: 9999999,
            value : 50000
        }
        
        
        await mockToken0Contract.connect(accounts[1]).approve(farmingContract.address, MaxUint256)

        await pairContract.connect(accounts[1]).approve(poolContract.address, MaxUint256)
        await farmingContract.connect(accounts[1]).invest(
            mockToken0Contract.address, 
            WMATICContract.address, 
            50000, 
            50000, 
            0,
            0,
            overridesFM);
        

        await pairContract.connect(accounts[1]).approve(poolContract.address, MaxUint256);
        data = await farmingContract.userInfo(mockToken0Contract.address, WMATICContract.address, accounts[1].address);
        console.log("userInfo: ", data);        

        // await pairContract.connect(accounts[1]).approve(routerContract.address, MaxUint256);
        // await farmingContract.connect(accounts[1]).withdraw(
        //     mockToken0Contract.address,
        //     WMATICContract.address, 
        //     3000, 
        //     0,
        //     0);

        // data = await mockRewardTokenContract.balanceOf(accounts[1].address);
        // console.log("balanceOf: ", data);

        // await farmingContract.connect(accounts[1]).harvest(
        //     mockToken0Contract.address, 
        //     WMATICContract.address
        //     );

        // data = await mockRewardTokenContract.balanceOf(accounts[1].address);
        // console.log("balanceOf: ", data);
    });
  
});
