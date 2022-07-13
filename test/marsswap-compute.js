const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");

describe("Mars, compute", function () {

    let accounts;
    let MarsswapFactoryContract;
    let mockToken0Contract;
    let mockToken1Contract;
    let WMATICContract;
    let routerContract;
    let ComputeLiquidityContract;

    const MaxUint256 = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

    const overrides = {
        gasLimit: 9999999
    }


    beforeEach(async function () { 
        accounts = await ethers.getSigners();

        MarsswapFactoryContract = await (await ethers.getContractFactory("MarsswapFactory")).deploy(accounts[0].address);
        
        const MockTokenContract = await ethers.getContractFactory("TokenERC20");
        mockToken0Contract = await MockTokenContract.deploy("TestToken", "CVTX");
        mockToken1Contract = await MockTokenContract.deploy("TestToken", "MTIX");

        WMATICContract = await (await ethers.getContractFactory("MarsswapMatic")).deploy();

        const swapFee = 30;
        const protocolFee = 5;
        await MarsswapFactoryContract.createPair(mockToken0Contract.address, mockToken1Contract.address, swapFee, protocolFee);
        await MarsswapFactoryContract.createPair(mockToken0Contract.address, WMATICContract.address, swapFee, protocolFee);

        routerContract = await (await ethers.getContractFactory("MarsswapRouter")).deploy(MarsswapFactoryContract.address, WMATICContract.address);
        ComputeLiquidityContract = await (await ethers.getContractFactory("MarsCompute")).deploy(MarsswapFactoryContract.address);

        await mockToken0Contract.approve(accounts[0].address, MaxUint256);
        await mockToken0Contract.transferFrom(accounts[0].address, accounts[1].address, ethers.utils.parseEther("100.0"));
        
        await mockToken1Contract.approve(accounts[0].address, MaxUint256);
        await mockToken1Contract.transferFrom(accounts[0].address, accounts[1].address, ethers.utils.parseEther("100.0"));
    });
    
    it("Liquidity In Value Out, getLiquidityValue", async function() {
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

        expect(await ComputeLiquidityContract.getLiquidityValue(mockToken0Contract.address, mockToken1Contract.address, 7071067811865475144n))
        .to.deep.eq([ethers.BigNumber.from(9999999999999999858n), ethers.BigNumber.from(4999999999999999929n)]);
    });

    it("Deadline setting", async function() {
        // 20 minutes from the current Unix time
        const deadline = Math.floor(Date.now() / 1000) + 60 * 20 
        // console.log("deadline: ", deadline);
    });

    it("Liquidity Share of pool", async function() {
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

        expect(await ComputeLiquidityContract.getShareOfPool(
            mockToken0Contract.address, 
            mockToken1Contract.address, 
            ethers.utils.parseEther("0.1"), 
            ethers.utils.parseEther("0.3"),
            false)).to.equals(99);        

        await mockToken0Contract.connect(accounts[1]).approve(routerContract.address, MaxUint256)
        await mockToken1Contract.connect(accounts[1]).approve(routerContract.address, MaxUint256)

        await routerContract.connect(accounts[1]).addLiquidity(
            mockToken0Contract.address,
            mockToken1Contract.address,
            ethers.utils.parseEther("0.1"),
            ethers.utils.parseEther("0.3"),
            0,
            0,
            accounts[1].address,
            MaxUint256,
            overrides
        )

        expect(await ComputeLiquidityContract.connect(accounts[1]).getShareOfPool(
            mockToken0Contract.address,
            mockToken1Contract.address,
            0,
            0,
            true)).to.equals(99);            
    }); 
});
