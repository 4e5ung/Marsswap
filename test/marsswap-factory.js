const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");

describe("Mars, factory", function () {

    let accounts;
    let MarsswapFactoryContract;
    let mockToken0Contract;
    let mockToken1Contract;
    let WMATICContract;
    let routerContract;

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
    });
   
    it("Change Swap Fee", async function() {
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

        pair = await MarsswapFactoryContract.getPair(mockToken0Contract.address, mockToken1Contract.address);
        pairContract = (await ethers.getContractFactory("MarsswapPair")).attach(pair);

        const swapFee = 10;
        const protocolFee = 1;

        await MarsswapFactoryContract.setSwapFee(mockToken0Contract.address, mockToken1Contract.address, swapFee);
        await MarsswapFactoryContract.setProtocolFee(mockToken0Contract.address, mockToken1Contract.address, protocolFee);

        expect(await pairContract.swapFee()).to.equals(swapFee);
        expect(await pairContract.protocolFee()).to.equals(protocolFee);
    });
});
