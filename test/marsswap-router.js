const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");
const { Bignumber } = require("ethers");

describe("Mars", function () {

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

        await mockToken0Contract.approve(accounts[0].address, MaxUint256);
        await mockToken0Contract.transferFrom(accounts[0].address, accounts[1].address, ethers.utils.parseEther("100.0"));
        
        await mockToken1Contract.approve(accounts[0].address, MaxUint256);
        await mockToken1Contract.transferFrom(accounts[0].address, accounts[1].address, ethers.utils.parseEther("100.0"));
    });

    it("factory, WMATIC", async function() {
        expect(await routerContract.factory()).to.eq(MarsswapFactoryContract.address)
        expect(await routerContract.WETH()).to.eq(WMATICContract.address)
    });

    it("addLiquidity", async function() {
        await mockToken0Contract.approve(routerContract.address, MaxUint256)
        await mockToken1Contract.approve(routerContract.address, MaxUint256)

        await routerContract.connect(accounts[0]).addLiquidity(
            mockToken0Contract.address,
            mockToken1Contract.address,
            10**4,
            10**4,
            0,
            0,
            accounts[0].address,
            MaxUint256,
            overrides
        )

        pair = await MarsswapFactoryContract.getPair(mockToken0Contract.address, mockToken1Contract.address);
        pairContract = (await ethers.getContractFactory("MarsswapPair")).attach(pair);

        expect(await pairContract.balanceOf(accounts[0].address)).to.equal(9900);
    });

    it("removeLiquidity", async function() {
        await mockToken0Contract.approve(routerContract.address, MaxUint256)
        await mockToken1Contract.approve(routerContract.address, MaxUint256)

        await routerContract.connect(accounts[0]).addLiquidity(
            mockToken0Contract.address,
            mockToken1Contract.address,
            10**2,
            10**4,
            0,
            0,
            accounts[0].address,
            MaxUint256,
            overrides
        )

        pair = await MarsswapFactoryContract.getPair(mockToken0Contract.address, mockToken1Contract.address);
        pairContract = (await ethers.getContractFactory("MarsswapPair")).attach(pair);
        expect(await pairContract.balanceOf(accounts[0].address)).to.equal(900);

        await pairContract.approve(routerContract.address, MaxUint256);
        await routerContract.removeLiquidity(
            mockToken0Contract.address,
            mockToken1Contract.address,
            100,
            0,
            0,
            accounts[0].address,
            MaxUint256,
            overrides
        )

        expect(await pairContract.balanceOf(accounts[0].address)).to.equal(800);
    });

    it("addLiquidityETH", async function() {
        await mockToken0Contract.approve(routerContract.address, MaxUint256)

        const overrides = {
            gasLimit: 9999999,
            value : ethers.utils.parseEther("50.0")
        }

        await routerContract.connect(accounts[0]).addLiquidityETH(
            mockToken0Contract.address,
            10**7,
            10**7,
            ethers.utils.parseEther("50.0"),
            accounts[0].address,
            MaxUint256,
            overrides
        )

        pair = await MarsswapFactoryContract.getPair(mockToken0Contract.address, WMATICContract.address);
        pairContract = (await ethers.getContractFactory("MarsswapPair")).attach(pair);

        expect(await WMATICContract.balanceOf(pairContract.address)).to.equal(50000000000000000000n);
        expect(await mockToken0Contract.balanceOf(pairContract.address)).to.equal(10**7);
        expect(await pairContract.balanceOf(accounts[0].address)).to.equal(22360679774897n);
    });
    

    it("removeLiquidityETH", async function() {
        await mockToken0Contract.approve(routerContract.address, MaxUint256)

        const overrides2 = {
            gasLimit: 9999999,
            value : ethers.utils.parseEther("50.0")
        }

        await routerContract.connect(accounts[0]).addLiquidityETH(
            mockToken0Contract.address,
            10**7,
            10**7,
            ethers.utils.parseEther("50.0"),
            accounts[0].address,
            MaxUint256,
            overrides2
        )

        pair = await MarsswapFactoryContract.getPair(mockToken0Contract.address, WMATICContract.address);
        pairContract = (await ethers.getContractFactory("MarsswapPair")).attach(pair);

        await pairContract.approve(routerContract.address, MaxUint256);

        await routerContract.removeLiquidityETH(
            mockToken0Contract.address,
            22360679774897,
            0,
            0,
            accounts[0].address,
            MaxUint256,
            overrides
        )

        expect(await pairContract.balanceOf(accounts[0].address)).to.equal(0);
    });

    
    it("swapExactTokensForTokens", async function() {
        await mockToken0Contract.approve(routerContract.address, MaxUint256)
        await mockToken1Contract.approve(routerContract.address, MaxUint256)

        //fee activate
        await MarsswapFactoryContract.setFeeTo(accounts[0].address);

        await routerContract.connect(accounts[0]).addLiquidity(
            mockToken0Contract.address,
            mockToken1Contract.address,
            ethers.utils.parseEther("1.0"),
            ethers.utils.parseEther("1000.0"),
            0,
            0,
            accounts[0].address,
            MaxUint256,
            overrides
        )

        pair = await MarsswapFactoryContract.getPair(mockToken0Contract.address, mockToken1Contract.address);
        pairContract = (await ethers.getContractFactory("MarsswapPair")).attach(pair);

        // swap estimate price
        let amountOuts = await routerContract.getAmountsOut(1000, [mockToken0Contract.address, mockToken1Contract.address]);

        // get beforeBalance
        let beforeBalance = await mockToken1Contract.balanceOf(pairContract.address);

        await routerContract.swapExactTokensForTokens(
            1000,
            0,
            [mockToken0Contract.address, mockToken1Contract.address],
            accounts[0].address,
            MaxUint256,
            overrides
        )

        // get afterBalance
        let afterBalance = await mockToken1Contract.balanceOf(pairContract.address);
        assert.equal( Number(beforeBalance.sub(afterBalance)), Number(amountOuts[1]) );

        // console.log("amounts", amountOuts[1])
        // console.log("beforeBalance", beforeBalance)
        // console.log("afterBalance", afterBalance)
        // console.log("data: ", beforeBalance.sub(afterBalance));          
    });

    it("swapTokensForExactTokens", async function() {
        await mockToken0Contract.approve(routerContract.address, MaxUint256)
        await mockToken1Contract.approve(routerContract.address, MaxUint256)

        //fee activate
        await MarsswapFactoryContract.setFeeTo(accounts[0].address);

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

        // swap estimate price
        amountsIn = await routerContract.getAmountsIn( 5000, [mockToken0Contract.address, mockToken1Contract.address])

        // // get beforeBalance
        let beforeBalance = await mockToken0Contract.balanceOf(pairContract.address);

        let slippagePercentage = 0.5;
        const slippageMax = 1 + slippagePercentage / 100;

        await routerContract.swapTokensForExactTokens(
            5000,
            Math.floor(amountsIn[0]*slippageMax),
            [mockToken0Contract.address, mockToken1Contract.address],
            accounts[0].address,
            MaxUint256,
            overrides
        )

      // get afterBalance
        let afterBalance = await mockToken0Contract.balanceOf(pairContract.address);

        assert.equal( Number(afterBalance.sub(beforeBalance)), Number(amountsIn[0]) );
    });

    it("swapExactTokensForETH", async function() {
        await mockToken0Contract.approve(routerContract.address, MaxUint256)

        const overrides2 = {
            gasLimit: 9999999,
            value : ethers.utils.parseEther("50.0")
        }

        await routerContract.connect(accounts[0]).addLiquidityETH(
            mockToken0Contract.address,
            ethers.utils.parseEther("10.0"),
            ethers.utils.parseEther("10.0"),
            ethers.utils.parseEther("50.0"),
            accounts[0].address,
            MaxUint256,
            overrides2
        )
    
        pair = await MarsswapFactoryContract.getPair(mockToken0Contract.address, WMATICContract.address);
        pairContract = (await ethers.getContractFactory("MarsswapPair")).attach(pair);

        // swap estimate price
        let amountOuts = await routerContract.getAmountsOut(5000, [mockToken0Contract.address, WMATICContract.address]);

        // get beforeBalance
        let beforeBalance = await WMATICContract.balanceOf(pairContract.address);

        await routerContract.swapExactTokensForETH(
            5000,
            0,
            [mockToken0Contract.address, WMATICContract.address],
            accounts[0].address,
            MaxUint256,
            overrides
        )

        // get afterBalance
        let afterBalance = await WMATICContract.balanceOf(pairContract.address);

        assert.equal( Number(beforeBalance.sub(afterBalance)), Number(amountOuts[1]) );
    });
    
    it("swapTokensForExactETH", async function() {
        await mockToken0Contract.approve(routerContract.address, MaxUint256)

        const overrides2 = {
            gasLimit: 9999999,
            value : ethers.utils.parseEther("50.0")
        }

        await routerContract.connect(accounts[0]).addLiquidityETH(
            mockToken0Contract.address,
            ethers.utils.parseEther("10.0"),
            ethers.utils.parseEther("10.0"),
            ethers.utils.parseEther("50.0"),
            accounts[0].address,
            MaxUint256,
            overrides2
        )
    
        pair = await MarsswapFactoryContract.getPair(mockToken0Contract.address, WMATICContract.address);
        pairContract = (await ethers.getContractFactory("MarsswapPair")).attach(pair);

        // swap estimate price
        let amountsIn = await routerContract.getAmountsIn(5000, [mockToken0Contract.address, WMATICContract.address]);

        // get beforeBalance
        let beforeBalance = await mockToken0Contract.balanceOf(pairContract.address);

        let slippagePercentage = 0.5;
        const slippageMax = 1 + slippagePercentage / 100;

        await routerContract.swapTokensForExactETH(
            5000,
            Math.floor(amountsIn[0]*slippageMax),
            [mockToken0Contract.address, WMATICContract.address],
            accounts[0].address,
            MaxUint256,
            overrides
        )

        // get afterBalance
        let afterBalance = await mockToken0Contract.balanceOf(pairContract.address);

        assert.equal( Number(afterBalance.sub(beforeBalance)), Number(amountsIn[0]) );
    });
    

    it("swapExactETHForTokens", async function() {
        await mockToken0Contract.approve(routerContract.address, MaxUint256)

        const overrides2 = {
            gasLimit: 9999999,
            value : ethers.utils.parseEther("50.0")
        }

        await routerContract.connect(accounts[0]).addLiquidityETH(
            mockToken0Contract.address,
            ethers.utils.parseEther("10.0"),
            ethers.utils.parseEther("10.0"),
            ethers.utils.parseEther("50.0"),
            accounts[0].address,
            MaxUint256,
            overrides2
        )
    
        pair = await MarsswapFactoryContract.getPair(mockToken0Contract.address, WMATICContract.address);
        pairContract = (await ethers.getContractFactory("MarsswapPair")).attach(pair);

        // swap estimate price
        let amountOuts = await routerContract.getAmountsOut(5000, [WMATICContract.address, mockToken0Contract.address]);


        // get beforeBalance
        let beforeBalance = await mockToken0Contract.balanceOf(pairContract.address);

        const overrides = {
            gasLimit: 9999999,
            value : 5000
        }

        await routerContract.swapExactETHForTokens(
            0,
            [WMATICContract.address, mockToken0Contract.address],
            accounts[0].address,
            MaxUint256,
            overrides
        )

        // get afterBalance
        let afterBalance = await mockToken0Contract.balanceOf(pairContract.address);

        assert.equal( Number(beforeBalance.sub(afterBalance)), Number(amountOuts[1]) );
    });

    it("swapETHForExactTokens", async function() {
        await mockToken0Contract.approve(routerContract.address, MaxUint256)

        const overrides2 = {
            gasLimit: 9999999,
            value : ethers.utils.parseEther("50.0")
        }

        await routerContract.connect(accounts[0]).addLiquidityETH(
            mockToken0Contract.address,
            ethers.utils.parseEther("10.0"),
            ethers.utils.parseEther("10.0"),
            ethers.utils.parseEther("50.0"),
            accounts[0].address,
            MaxUint256,
            overrides2
        )
    
        pair = await MarsswapFactoryContract.getPair(mockToken0Contract.address, WMATICContract.address);
        pairContract = (await ethers.getContractFactory("MarsswapPair")).attach(pair);

        // swap estimate price
        let amountsIn = await routerContract.getAmountsIn(5000, [WMATICContract.address, mockToken0Contract.address]);

        // get beforeBalance
        let beforeBalance = await WMATICContract.balanceOf(pairContract.address);

        const overrides3 = {
            gasLimit: 9999999,
            value : amountsIn[0]
        }

        await routerContract.swapETHForExactTokens(
            5000,
            [WMATICContract.address, mockToken0Contract.address],
            accounts[0].address,
            MaxUint256,
            overrides3
        )

        // get afterBalance
        let afterBalance = await WMATICContract.balanceOf(pairContract.address);

        assert.equal( Number(afterBalance.sub(beforeBalance)), Number(amountsIn[0]) );
    });

    it("Estimate Price, getAmountsOut", async function() {
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

        expect(await routerContract.getAmountsOut(10000, [mockToken0Contract.address, mockToken1Contract.address])).to.deep.eq([ethers.BigNumber.from(10000), ethers.BigNumber.from(4984)]);
        //ethers.utils.formatUnits(ethers.BigNumber.from(498), 18)        
    });

    
    it("Estimate Price, getAmountsIn", async function() {
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

        let slippagePercentage = 0.5;
        const slippageMax = 1 + slippagePercentage / 100;

        expect(await routerContract.getAmountsIn( 5000, [mockToken0Contract.address, mockToken1Contract.address])).to.deep.eq([ethers.BigNumber.from(10031), ethers.BigNumber.from(5000)]);
        assert.equal( ethers.BigNumber.from(10031)*slippageMax, 10081.154999999999 );
    });

    it("Estimate Slippage, getAmountsOut", async function() {
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

        let slippagePercentage = 0.5;
        const slippage = 1- slippagePercentage / 100;

        expect(await routerContract.getAmountsOut(1000, [mockToken0Contract.address, mockToken1Contract.address])).to.deep.eq([ethers.BigNumber.from(1000), ethers.BigNumber.from(498)]);
        assert.equal( ethers.BigNumber.from(498)*slippage, 495.51 );

        // let slippageAmount = ethers.BigNumber.from(498)*slippage;
        // console.log("slippageAmount: ", slippageAmount);

        //ethers.utils.formatUnits(ethers.BigNumber.from(498), 18)        
    });

    it("Price impact", async function() {
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

        amountIn = 10000;

        expect(await routerContract.getPriceImpact(amountIn, [mockToken0Contract.address, mockToken1Contract.address])).to.equals(2);
    });
});
