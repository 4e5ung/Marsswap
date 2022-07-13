const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");
const { Bignumber } = require("ethers");

describe("Mars", function () {

    let accounts;
    let tokenContract;
    let stakeCoinContract;
    let stakeTokenContract;
    let provider = waffle.provider;
    let MarsswapFactoryContract;
    let mockToken0Contract;
    let mockToken1Contract;
    let WMATICContract;
    let routerContract;
    let liquidity;
    let pairContract;
    let ComputeLiquidityContract;
    let OracleContract;
    let MarsswapStakingFactoryContract;
    let mockRewardTokenContract;

    const MaxUint256 = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

    const overrides = {
        gasLimit: 9999999
    }


    beforeEach(async function () { 
        accounts = await ethers.getSigners();

    
        const routerFactory = await ethers.getContractFactory("MarsswapRouter");

        routerContract = routerFactory.attach('0x500c2Cb8fD307710D0E109130c74657BD3D555E0');
    });

    it("factory, WMATIC", async function() {
        
        console.log("routerContract: ", routerContract.address);
        
        const MockTokenContract = await ethers.getContractFactory("TokenERC20");
        mockToken0Contract = MockTokenContract.attach('0xB36251BE91f78b24533e746992509000E20bde46');
        mockToken1Contract = MockTokenContract.attach('0x3F2c28b656e2B40FB8Ff9517dB0286A412b62EE3');
        
        
        // 초기 LP 생성
        // await mockToken0Contract.approve(routerContract.address, MaxUint256)
        // await mockToken1Contract.approve(routerContract.address, MaxUint256)

        // await routerContract.addLiquidity(
        //     mockToken0Contract.address,
        //     mockToken1Contract.address,
        //     ethers.utils.parseEther("10000"),
        //     ethers.utils.parseEther("10000"),
        //     0,
        //     0,
        //     '0x46C65D87bE47255882561bcc7CFf3bBA186F0848',
        //     MaxUint256,
        //     overrides
        // )

      

        
        // codeHash = await MarsswapFactoryContract.pairCodeHash();
        // console.log("pairCodeHash codeHash: ", codeHash);

        // expect(await routerContract.factory()).to.eq(MarsswapFactoryContract.address)
        // expect(await routerContract.WETH()).to.eq(WMATICContract.address)

                


        // console.log("mockToken0Contract: ", mockToken0Contract.address);
        // console.log("mockToken1Contract: ", mockToken1Contract.address);


        // amounts = await routerContract.getAmountsOut(1000, [mockToken0Contract.address, mockToken1Contract.address])
        // console.log("data: ", amounts);


        balance = await mockToken0Contract.balanceOf('0x2b596D778DA594744739fE41ea02BC8E28672a0B');
        console.log("balance: ", balance)

        balance = await mockToken1Contract.balanceOf('0x2b596D778DA594744739fE41ea02BC8E28672a0B');
        console.log("balance: ", balance)

        // data = await mockToken0Contract.approve('0x08EC5340C267Cddb7b0AB274f5F338615789d714', 1000000);
        // console.log("data: ", data);
        // data = await mockToken1Contract.approve('0x08EC5340C267Cddb7b0AB274f5F338615789d714', 1000000);
        
        // await routerContract.swapExactTokensForTokens(
        //     1000,
        //     0,
        //     [mockToken1Contract.address, mockToken0Contract.address],
        //     '0x46C65D87bE47255882561bcc7CFf3bBA186F0848',
        //     MaxUint256,
        //     overrides
        // )

        // balance = await mockToken0Contract.balanceOf('0x406fAa12f9A9bbf94D636E00eF9957a6305A0cE5');
        // console.log("balance: ", balance)

        // balance = await mockToken1Contract.balanceOf('0x406fAa12f9A9bbf94D636E00eF9957a6305A0cE5');
        // console.log("balance: ", balance)
    });

   
  
});
