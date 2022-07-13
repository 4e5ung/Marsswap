// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './libraries/MarsswapLibrary.sol';
import './libraries/TransferHelper.sol';
import './interfaces/IMarsswapFactory.sol';
import './interfaces/IMarsswapRouter.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

import './console.sol';


contract MarsswapRouter {
    address public factory;
    address public WETH;

    uint256 maxPriceImpact = 500;   //  3.33%

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'MarsswapRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal view virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        require(IMarsswapFactory(factory).getPair(tokenA, tokenB) != address(0), 'MarsswapRouter: ZERO_ADDRESS');

        (uint reserveA, uint reserveB) = MarsswapLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = MarsswapLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'MarsswapRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = MarsswapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'MarsswapRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = MarsswapLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, to, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, to, pair, amountB);
        liquidity = IMarsswapPair(pair).mint(to);
    }
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = MarsswapLibrary.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, to, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IMarsswapPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(to, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = MarsswapLibrary.pairFor(factory, tokenA, tokenB);
        IMarsswapPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IMarsswapPair(pair).burn(to);
        (address token0,) = MarsswapLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'MarsswapRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'MarsswapRouter: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountToken, uint amountETH) {
        address pair = MarsswapLibrary.pairFor(factory, token, WETH);
        IMarsswapPair(pair).transferFrom(to, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IMarsswapPair(pair).burn(address(this));
        (address token0,) = MarsswapLibrary.sortTokens(token, WETH);
        (amountToken, amountETH) = token == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountToken >= amountTokenMin, 'MarsswapRouter: INSUFFICIENT_A_AMOUNT');
        require(amountETH >= amountETHMin, 'MarsswapRouter: INSUFFICIENT_B_AMOUNT');
        // (amountToken, amountETH) = removeLiquidity(
        //     token,
        //     WETH,
        //     liquidity,
        //     amountTokenMin,
        //     amountETHMin,
        //     address(this),
        //     deadline
        // );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual returns (uint amountA, uint amountB) {
        address pair = MarsswapLibrary.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? type(uint256).max : liquidity;
        IMarsswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual returns (uint amountToken, uint amountETH) {
        address pair = MarsswapLibrary.pairFor(factory, token, WETH);
        uint value = approveMax ? type(uint256).max : liquidity;
        IMarsswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = MarsswapLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? MarsswapLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IMarsswapPair(MarsswapLibrary.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        amounts = MarsswapLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'MarsswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');

        uint256 priceImpact = getPriceImpact(amountIn, path);
        require(priceImpact <= maxPriceImpact, 'MarsswapRouter: OVER_PRICE_IMPACT');


        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MarsswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        amounts = MarsswapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'MarsswapRouter: EXCESSIVE_INPUT_AMOUNT');

        uint256 priceImpact = getPriceImpact(amounts[0], path);
        require(priceImpact <= maxPriceImpact, 'MarsswapRouter: OVER_PRICE_IMPACT');

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MarsswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'MarsswapRouter: INVALID_PATH');
        amounts = MarsswapLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'MarsswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');

        uint256 priceImpact = getPriceImpact(msg.value, path);
        require(priceImpact <= maxPriceImpact, 'MarsswapRouter: OVER_PRICE_IMPACT');

        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(MarsswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'MarsswapRouter: INVALID_PATH');
        amounts = MarsswapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'MarsswapRouter: EXCESSIVE_INPUT_AMOUNT');

        uint256 priceImpact = getPriceImpact(amounts[0], path);
        require(priceImpact <= maxPriceImpact, 'MarsswapRouter: OVER_PRICE_IMPACT');


        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MarsswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'MarsswapRouter: INVALID_PATH');
        amounts = MarsswapLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'MarsswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');

        uint256 priceImpact = getPriceImpact(amountIn, path);
        require(priceImpact <= maxPriceImpact, 'MarsswapRouter: OVER_PRICE_IMPACT');


        TransferHelper.safeTransferFrom(
            path[0], msg.sender, MarsswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'MarsswapRouter: INVALID_PATH');
        amounts = MarsswapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'MarsswapRouter: EXCESSIVE_INPUT_AMOUNT');

        uint256 priceImpact = getPriceImpact(amounts[0], path);
        require(priceImpact <= maxPriceImpact, 'MarsswapRouter: OVER_PRICE_IMPACT');

        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(MarsswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual returns (uint amountB) {
        return MarsswapLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint8 swapFee)
        public
        view
        virtual
        returns (uint amountOut)
    {
        return MarsswapLibrary.getAmountOut(amountIn, reserveIn, reserveOut, swapFee);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, uint8 swapFee)
        public
        view
        virtual
        returns (uint amountIn)
    {
        return MarsswapLibrary.getAmountIn(amountOut, reserveIn, reserveOut, swapFee);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        returns (uint[] memory amounts)
    {
        return MarsswapLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        returns (uint[] memory amounts)
    {
        return MarsswapLibrary.getAmountsIn(factory, amountOut, path);
    }

    
    function getPriceImpact(
        uint256 srcAmount,
        address[] memory path
    ) public view returns (uint256 priceImpact) {
        uint256 amountInFee = srcAmount;
        uint[] memory amounts = MarsswapLibrary.getAmountsOut(factory, srcAmount, path);
        uint256 destAmount = amounts[amounts.length - 1];

        (uint256 reserveIn, uint256 reserveOut) = MarsswapLibrary.getReserves(
            factory,
            path[0],
            path[1]
        );    
    
        amountInFee = MarsswapLibrary.quote((amountInFee*(10000-(IMarsswapPair(MarsswapLibrary.pairFor(factory, path[0], path[1])).swapFee())))/(10000), reserveIn, reserveOut);

        if (amountInFee <= destAmount) {
            priceImpact = 0;
        } else {
            priceImpact = (((amountInFee - destAmount) * 10000) / amountInFee);
        }
    }
}
