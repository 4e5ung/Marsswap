// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './MarsswapStakingPool.sol';
import "./access/Ownable.sol";

contract MarsswapStakingFactory is Ownable {
    event PoolCreated(address indexed newPool);

    mapping(address => address) public getPool;
    address[] public allPools;
    

    constructor() {
        //
    }

    function allPoolsLength() external view returns (uint) {
        return allPools.length;
    }

    /*
     * @notice Deploy the pool
     * @param _stakedToken: staked token address
     * @param _rewardToken: reward token address
     * @param _rewardPerSecond: reward per block (in rewardToken)
     * @param _startTimestamp: start block
     * @param _endBlock: end block
     * @param _poolLimitPerUser: pool limit per user in stakedToken (if any, else 0)
     * @param _admin: admin address with ownership
     * @return address of new smart chef contract
     */
    function deployPool(
        address _stakedToken,
        address _rewardToken,
        uint256 _rewardPerSecond,
        uint256 _startTimestamp,
        uint256 _bonusEndTimestamp,
        uint256 _poolLimitPerUser,
        address _admin
    ) external onlyOwner returns(MarsswapStakingPool pool){
        require(IERC20(_stakedToken).totalSupply() >= 0);
        require(IERC20(_rewardToken).totalSupply() >= 0);
        require(_stakedToken != _rewardToken, "Tokens must be be different");
        require(getPool[_stakedToken] == address(0), 'MarsswapStakingFactory: POOL_EXISTS');
        
        pool = new MarsswapStakingPool();

        pool.initialize(
            _stakedToken,
            _rewardToken,
            _rewardPerSecond,
            _startTimestamp,
            _bonusEndTimestamp,
            _poolLimitPerUser,
            _admin
        );

        getPool[_stakedToken] = address(pool);
        allPools.push(address(pool));

        emit PoolCreated(address(pool));
    }
}
