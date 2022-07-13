// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './access/Ownable.sol';
import "./interfaces/IERC20.sol";
import "./security/ReentrancyGuard.sol";
import './libraries/TransferHelper.sol';


import './interfaces/IMarsswapRouter.sol';
import './interfaces/IMarsswapFactory.sol';
import './interfaces/IMarsswapStakingPool.sol';
import './interfaces/IMarsswapPair.sol';

import "./console.sol";

contract MarsswapStakingPool is Ownable, ReentrancyGuard {
    // The address of the smart factory
    address public factory;

    // Whether a limit is set for users
    bool public hasUserLimit;

    // Whether it is initialized
    bool public isInitialized;

    // Accrued token per share
    uint256 public accTokenPerShare;

    // The block number when WAGYU mining ends.
    uint256 public bonusEndTimestamp;

    // The block number when WAGYU mining starts.
    uint256 public startTimestamp;

    // The block number of the last pool update
    uint256 public lastRewardTimestamp;

    // The pool limit (0 if none)
    uint256 public poolLimitPerUser;

    // WAGYU tokens created per block.
    uint256 public rewardPerSecond;

    // The precision factor
    uint256 public PRECISION_FACTOR;

    // The reward token
    address public rewardToken;

    // The staked token
    address public stakedToken;

    address token0;
    address token1;
    address router;

    int32 public deadlineSeconds = 180 seconds;

    // Info of each user that stakes tokens (stakedToken)
    mapping(address => UserInfo) public userInfo;

    struct UserInfo {
        uint256 amount; // How many staked tokens the user has provided
        uint256 rewardDebt; // Reward debt
    }

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event NewStartAndEndBlocks(uint256 startTimestamp, uint256 endBlock);
    event NewrewardPerSecond(uint256 rewardPerSecond);
    event NewPoolLimit(uint256 poolLimitPerUser);
    event RewardsStop(uint256 blockNumber);
    event Withdraw(address indexed user, uint256 amount);

    constructor() {
        factory = msg.sender;
    }

    /*
     * @notice Initialize the contract
     * @param _stakedToken: staked token address
     * @param _rewardToken: reward token address
     * @param _rewardPerSecond: reward per block (in rewardToken)
     * @param _startTimestamp: start block
     * @param _bonusEndTimestamp: end block
     * @param _poolLimitPerUser: pool limit per user in stakedToken (if any, else 0)
     * @param _admin: admin address with ownership
     */
    function initialize(
        address _stakedToken,
        address _rewardToken,
        uint256 _rewardPerSecond,
        uint256 _startTimestamp,
        uint256 _bonusEndTimestamp,
        uint256 _poolLimitPerUser,  // 최대 pool 보관량
        address _admin
    ) external {
        require(!isInitialized, "Already initialized");
        require(msg.sender == factory, "Not factory");

        // Make this contract initialized
        isInitialized = true;

        stakedToken = _stakedToken;
        rewardToken = _rewardToken;
        rewardPerSecond = _rewardPerSecond;
        startTimestamp = _startTimestamp;
        bonusEndTimestamp = _bonusEndTimestamp;

        if (_poolLimitPerUser > 0) {
            hasUserLimit = true;
            poolLimitPerUser = _poolLimitPerUser;
        }

        uint256 decimalsRewardToken = uint256(IERC20(rewardToken).decimals());
        require(decimalsRewardToken < 30, "Must be inferior to 30");

        PRECISION_FACTOR = uint256(10**(uint256(30)-(decimalsRewardToken)));

        // Set the lastRewardTimestamp as the startTimestamp
        lastRewardTimestamp = startTimestamp;

        // Transfer ownership to the admin address who becomes owner of the contract
        transferOwnership(_admin);
    }

    /*
     * @notice Deposit staked tokens and collect reward tokens (if any)
     * @param _amount: amount to withdraw (in rewardToken)
     */
    function deposit(uint256 _amount, address _from) external {
        UserInfo storage user = userInfo[_from];

        if (hasUserLimit) {
            // 개인 스테이킹 양이 poolLimitPerUser 을 넘을 수 없다.
            require((_amount+user.amount) <= poolLimitPerUser, "User amount above limit");
        }

        _updatePool();

        if (user.amount > 0) {
            // ((기존 개인 스테이킹 한 양 * 공유Token) / 10**12) - rewardDebt
            uint256 pending = ((user.amount*accTokenPerShare)/(PRECISION_FACTOR))-user.rewardDebt;
            if (pending > 0) {
                // rewardToken.safeTransfer(address(msg.sender), pending);
               TransferHelper.safeTransfer(rewardToken, address(_from), pending);
            }
        }

        if (_amount > 0) {
            // 기존 개인 스테이킹 양에 추가 개인 스테이킹
            user.amount = user.amount+_amount;
            // stakedToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            TransferHelper.safeTransferFrom(stakedToken, address(_from), address(this), _amount);
            // TransferHelper.safeApprove(stakedToken, address(this), _amount);
        }

        // (개인 스테이킹 양 * 공유Token) / 10**12
        user.rewardDebt = (user.amount*accTokenPerShare)/PRECISION_FACTOR;

        emit Deposit(_from, _amount);
    }

    /*
     * @notice Withdraw staked tokens and collect reward tokens
     * @param _amount: amount to withdraw (in rewardToken)
     */
    function withdraw(uint256 _amount, address _from) external nonReentrant {
        UserInfo storage user = userInfo[_from];
        require(user.amount >= _amount, "Amount to withdraw too high");

        _updatePool();

        // ((기존 개인 스테이킹 한 양 * accTokenPerShare) / 10**12) - rewardDebt
        uint256 pending = ((user.amount*accTokenPerShare)/PRECISION_FACTOR)-user.rewardDebt;
        // console.log("pending: ", pending);

        if (_amount > 0) {
            user.amount = user.amount-_amount;
            // stakedToken.safeTransfer(address(msg.sender), _amount);
            // 요청한 개인 스테이킹 양만큼 제거
            TransferHelper.safeTransfer(stakedToken, address(_from), _amount);
        }

        if (pending > 0) {
            // rewardToken.safeTransfer(address(msg.sender), pending);

            // pending 금액만큼 Reward
            TransferHelper.safeTransfer(rewardToken, address(_from), pending);
        }

        // (개인 스테이킹 양 * accTokenPerShare) / 10**12
        user.rewardDebt = (user.amount*accTokenPerShare)/PRECISION_FACTOR;

        emit Withdraw(_from, _amount);
    }

    /*
     * @notice Withdraw staked tokens without caring about rewards rewards
     * @dev Needs to be for emergency.
     */
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amountToTransfer = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        if (amountToTransfer > 0) {
            // stakedToken.safeTransfer(address(msg.sender), amountToTransfer);
            TransferHelper.safeTransfer(stakedToken, address(msg.sender), amountToTransfer);
        }

        emit EmergencyWithdraw(msg.sender, user.amount);
    }

    /*
     * @notice Stop rewards
     * @dev Only callable by owner. Needs to be for emergency.
     */
    function emergencyRewardWithdraw(uint256 _amount) external onlyOwner {
        // rewardToken.safeTransfer(address(msg.sender), _amount);
        TransferHelper.safeTransfer(rewardToken, address(msg.sender), _amount);
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of tokens to withdraw
     * @dev This function is only callable by admin.
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress != address(stakedToken), "Cannot be staked token");
        require(_tokenAddress != address(rewardToken), "Cannot be reward token");

        // _tokenAddress.safeTransfer(address(msg.sender), _tokenAmount);
        TransferHelper.safeTransfer(_tokenAddress, address(msg.sender), _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /*
     * @notice Stop rewards
     * @dev Only callable by owner
     */
    function stopReward() external onlyOwner {
        bonusEndTimestamp = block.timestamp;
    }

    /*
     * @notice Update pool limit per user
     * @dev Only callable by owner.
     * @param _hasUserLimit: whether the limit remains forced
     * @param _poolLimitPerUser: new pool limit per user
     */
    function updatePoolLimitPerUser(bool _hasUserLimit, uint256 _poolLimitPerUser) external onlyOwner {
        require(hasUserLimit, "Must be set");
        if (_hasUserLimit) {
            require(_poolLimitPerUser > poolLimitPerUser, "New limit must be higher");
            poolLimitPerUser = _poolLimitPerUser;
        } else {
            hasUserLimit = _hasUserLimit;
            poolLimitPerUser = 0;
        }
        emit NewPoolLimit(poolLimitPerUser);
    }

    /*
     * @notice Update reward per block
     * @dev Only callable by owner.
     * @param _rewardPerSecond: the reward per block
     */
    function updaterewardPerSecond(uint256 _rewardPerSecond) external onlyOwner {
        require(block.timestamp < startTimestamp, "Pool has started");
        rewardPerSecond = _rewardPerSecond;
        emit NewrewardPerSecond(_rewardPerSecond);
    }

    /**
     * @notice It allows the admin to update start and end blocks
     * @dev This function is only callable by owner.
     * @param _startTimestamp: the new start block
     * @param _bonusEndTimestamp: the new end block
     */
    function updateStartAndEndBlocks(uint256 _startTimestamp, uint256 _bonusEndTimestamp) external onlyOwner {
        require(block.timestamp < startTimestamp, "Pool has started");
        require(_startTimestamp < _bonusEndTimestamp, "New startTimestamp must be lower than new endBlock");
        require(block.timestamp < _startTimestamp, "New startTimestamp must be higher than current block");

        startTimestamp = _startTimestamp;
        bonusEndTimestamp = _bonusEndTimestamp;

        // Set the lastRewardTimestamp as the startTimestamp
        lastRewardTimestamp = startTimestamp;

        emit NewStartAndEndBlocks(_startTimestamp, _bonusEndTimestamp);
    }

    /*
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingReward(address _user) internal view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 stakedTokenSupply = IERC20(stakedToken).balanceOf(address(this));

        if (block.timestamp > lastRewardTimestamp && stakedTokenSupply != 0) {
            uint256 multiplier = _getMultiplier(lastRewardTimestamp, block.timestamp);
            uint256 reward = multiplier*rewardPerSecond;
            uint256 adjustedTokenPerShare = accTokenPerShare+(((reward*PRECISION_FACTOR)/stakedTokenSupply));
            return ((user.amount*adjustedTokenPerShare)/PRECISION_FACTOR)-user.rewardDebt;
        } else {
            return ((user.amount*accTokenPerShare)/PRECISION_FACTOR)-user.rewardDebt;
        }
    }

    function userState( address _user ) external view returns (uint256 amount, uint256 rewardDebt){
        UserInfo storage user = userInfo[_user];
        
        amount = user.amount;

        if( amount > 0 )
            rewardDebt = pendingReward(_user);
    }

    /*
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function _updatePool() internal {
        
        if (block.timestamp <= lastRewardTimestamp) {
            return;
        }

        uint256 stakedTokenSupply = IERC20(stakedToken).balanceOf(address(this));

        if (stakedTokenSupply == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }

        // _getMultiplier(마지막 시간, 현재시간)
        uint256 multiplier = _getMultiplier(lastRewardTimestamp, block.timestamp);
        // 12 * (최소:보정시간, 최대: (현재시간-마지막시간) pool업데이트시간)
        uint256 reward = multiplier*rewardPerSecond;
        // accTokenPerShare + ((reward * 10**12) / (전체 스테이크 토큰양))
        accTokenPerShare = accTokenPerShare+(((reward*PRECISION_FACTOR)/stakedTokenSupply));
        lastRewardTimestamp = block.timestamp;
    }

    /*
     * @notice Return reward multiplier over the given _from to _to block.
     * @param _from: block to start (마지막 update시간)
     * @param _to: block to finish  (현재시간)
     */
    function _getMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        // console.log("_getMultiplier, block.timestamp: ", _to);
        // console.log("_getMultiplier, lastRewardTimestamp: ", _from);
        // console.log("_getMultiplier, bonusEndTimestamp: ", bonusEndTimestamp);
        

        if (_to <= bonusEndTimestamp) { //  현재시간 <= (보상 마지막시간)
            return _to-_from;  //  현재시간-마지막시간뺀차
        } else if (_from >= bonusEndTimestamp) {    // 마지막업데이트시간 >= (보상 마지막시간)
            return 0;
        } else {
            return bonusEndTimestamp-_from;//  (보상 마지막시간) - 마지막시간
        }
    }
}
