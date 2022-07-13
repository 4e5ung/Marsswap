// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import './interfaces/IMarsswapRouter.sol';
import './interfaces/IMarsswapFactory.sol';
import './interfaces/IMarsswapStakingPool.sol';
import './interfaces/IMarsswapPair.sol';
import './interfaces/IMarsswapStakingFactory.sol';

import './libraries/MarsswapLibrary.sol';
import './libraries/TransferHelper.sol';

import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';
import "./security/ReentrancyGuard.sol";
import "./access/Ownable.sol";

import './console.sol';

contract MarsswapFarming is Ownable, ReentrancyGuard {
    event PoolCreated(address indexed newPool);

    mapping(address => address) public getFarm;
    address[] public allPools;

    uint32 public deadlineSeconds = 180 seconds;

    address stakeFactory;
    address router;
    address factory;
    address WETH;
    
    constructor(
        address _router,
        address _stakeFactory,
        address _admin
    ) {
        router = _router;
        stakeFactory = _stakeFactory;
        factory = IMarsswapRouter(router).factory();
        WETH = IMarsswapRouter(router).WETH();
        
        transferOwnership(_admin);
    }

    modifier invalid(address _token0, address _token1) {
        require(_token0 != address(0), "MarsswapFarming, _token0 none");
        require(_token1 != address(0), "MarsswapFarming, _token1 none");
        _;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'MarsswapFarming: EXPIRED');
        _;
    }

    function setRouter(address _router) public onlyOwner(){
        router = _router;
    }

    function setDeadlineSeconds(uint32 _deadlineSeconds) public onlyOwner() {
        deadlineSeconds = _deadlineSeconds;
    }
  
    function setStakeFactory(address _stakeFactory) public onlyOwner(){
        stakeFactory = _stakeFactory;
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal view virtual returns (uint amountA, uint amountB) {
        require(IMarsswapFactory(factory).getPair(tokenA, tokenB) != address(0), 'MarsswapFarming: ZERO_ADDRESS');

        (uint reserveA, uint reserveB) = MarsswapLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = MarsswapLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'MarsswapFarming: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {

                uint amountAOptimal = MarsswapLibrary.quote(amountBDesired, reserveB, reserveA);                
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'MarsswapFarming: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function invest( 
        address _token0,
        address _token1,
        uint256 _amount0,
        uint256 _amount1, 
        uint256 _minAmount0, 
        uint256 _minAmount1
    ) external payable nonReentrant invalid(_token0, _token1){
        require(_amount0 > 0, "MarsswapFarming, amount0 ZERO");
        require(_amount1 > 0, "MarsswapFarming, amount1 ZERO");

        if( _token1 == address(WETH) ){
            require( msg.value == _amount1, "MarsswapFarming, value error");
        }

        (uint amountA, uint amountB) = _addLiquidity(_token0, _token1, _amount0, _amount1, _minAmount0, _minAmount1);

        address pair = MarsswapLibrary.pairFor(factory, _token0, _token1);
        TransferHelper.safeTransferFrom(_token0, msg.sender, pair, amountA);

        if( _token1 == address(WETH) ){
            IWETH(WETH).deposit{value: amountB}();
            assert(IWETH(WETH).transfer(pair, amountB));
        }else{
            TransferHelper.safeTransferFrom(_token1, msg.sender, pair, amountB);
        }

        uint _liquidity = IMarsswapPair(pair).mint(msg.sender);
        
        if( _token1 == address(WETH) ){
            if (msg.value > amountB) TransferHelper.safeTransferETH(msg.sender, msg.value - amountB);
        }

        require(_liquidity > 0, "MarsswapFarming, liquidity ZERO");

        address pool = getPool(_token0, _token1);

        IMarsswapStakingPool(pool).deposit(_liquidity, msg.sender);
    }

    function withdraw( 
        address _token0,
        address _token1,
        uint256 _liquidity, 
        uint256 _minAmount0, 
        uint256 _minAmount1 
    ) external nonReentrant invalid(_token0, _token1){
        require(_liquidity > 0, "MarsswapFarming, _amount zero");

        address pool = getPool(_token0, _token1);

        (uint256 amount, ) = IMarsswapStakingPool(pool).userState(msg.sender);
        require( amount > 0, "MarsswapFarming, amount zero");
        require( amount >= _liquidity, "MarsswapFarming, Over amount");

        IMarsswapStakingPool(pool).withdraw(_liquidity, msg.sender);

        if( _token1 == address(WETH) ){
            IMarsswapRouter(router).removeLiquidityETH(
                _token0, 
                _liquidity, 
                _minAmount0,
                _minAmount1,
                msg.sender, 
                block.timestamp+deadlineSeconds
            );
        }else{
            IMarsswapRouter(router).removeLiquidity(
                _token0, 
                _token1, 
                _liquidity, 
                _minAmount0,
                _minAmount1,
                msg.sender, 
                block.timestamp+deadlineSeconds
            );
        }
    }

    function harvest( 
        address _token0, 
        address _token1 
    ) external nonReentrant invalid(_token0, _token1){
        require(_token0 != address(0), "MarsswapFarming, _token0 none");
        require(_token1 != address(0), "MarsswapFarming, _token1 none");

        address pool = getPool(_token0, _token1);

        (uint256 amount, ) = IMarsswapStakingPool(pool).userState(msg.sender);
        require( amount > 0, "MarsswapFarming, amount zero");

        IMarsswapStakingPool(pool).withdraw(0, msg.sender);
    }

    function userInfo( 
        address _token0, 
        address _token1,
        address _user
    ) external view invalid(_token0, _token1) returns(uint256, uint256){
        address pool = getPool(_token0, _token1);

        return IMarsswapStakingPool(pool).userState(_user);
    }

    function getPool( address _token0, address _token1 ) internal view returns(address pool){
        pool = IMarsswapStakingFactory(stakeFactory).getPool(IMarsswapFactory(IMarsswapRouter(router).factory()).getPair(_token0, _token1));
    }
}
