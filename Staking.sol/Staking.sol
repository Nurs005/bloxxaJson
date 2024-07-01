// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Staking contract with static APR.
/// @notice Reward rate must be set at the base point.

contract Staking is Ownable {
    IERC20 public stakingToken; // Reward token.
    uint256 public rewardRate; // Annual Percentage Rate at base point.
    uint256 public lockPeriod; // Period when user can't withdraw stake.
    uint256 public minStake;
    uint256 public maxStake;
    uint public poolValue; // Reward pool available;
    uint public totalStaked; // Total staked amount;

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 lastClaimTimestamp;
    }

    mapping(address => uint256) public userTotalStaked;
    mapping(address => Stake[]) public stakes;

    /// @param _stakingToken Reward token address.
    /// @param _minStake Minimal amount available stake.
    /// @param _maxStake Maximal amount available stake. 
    /// @param _lockPeriod  Period when user can't withdraw stake.
    /// @param _rewardRate Annual Percentage Rate at base point.
    /// @param _initialAddress Owner address.
    /// @param _poolValue  Total reward amount.

    constructor(
    address _stakingToken, 
    uint256 _minStake, 
    uint256 _maxStake,
    uint256 _lockPeriod,
    uint256 _rewardRate, 
    address _initialAddress, 
    uint _poolValue
    )Ownable(_initialAddress) {
        stakingToken = IERC20(_stakingToken);
        rewardRate = _rewardRate;
        lockPeriod = _lockPeriod;
        minStake = _minStake;
        maxStake = _maxStake;
        poolValue = _poolValue;
    }

    /// @param userAddress The address for which the reward is calculated.
    /// @param stakeIndex Stake count.

    function calculateReward(address userAddress, uint256 stakeIndex) public view returns (uint256 rewardAmount){
        Stake memory userStake = stakes[userAddress][stakeIndex];
        uint256 elapsedSeconds = block.timestamp - userStake.lastClaimTimestamp;
        rewardAmount = (userStake.amount * elapsedSeconds * rewardRate) / (10000 * 365 days);
    }

    function getUserStakes(address userAddress) external view returns (Stake[] memory userStakes) {
        return stakes[userAddress];
    }

    function stake(uint256 _amount) public {
        require(_amount >= minStake, "The amount must be greater than minimum");
        require(userTotalStaked[msg.sender] <= maxStake, "Max stake amount reached");

        userTotalStaked[msg.sender] += _amount;
        stakes[msg.sender].push(Stake(_amount, block.timestamp, block.timestamp));
        totalStaked += _amount;
        require(stakingToken.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
    }

    /// @param stakeIndex Stake count.

    function claimReward(uint256 stakeIndex) public {
        uint256 rewardAmount = calculateReward(msg.sender, stakeIndex);
        stakes[msg.sender][stakeIndex].lastClaimTimestamp = block.timestamp;
        require(stakingToken.transfer(msg.sender, rewardAmount), "Token transfer failed");
        poolValue -= rewardAmount;
    }

    /// @notice Claim reward for all user stakes.

    function claimAllRewards() external {
        Stake[] memory userStakes = stakes[msg.sender];
        for(uint256 i; i < userStakes.length; i++) {
            claimReward(i);
        }
    }

    /// @notice Withdraw only one stake with reward.

    function withdraw(uint256 stakeIndex) public  {
        Stake storage userStake = stakes[msg.sender][stakeIndex];
        uint256 elapsedSeconds = block.timestamp - userStake.startTime;

        require(elapsedSeconds > lockPeriod, "Early withdrawal is not allowed");

        uint256 rewardAmount = calculateReward(msg.sender, stakeIndex);
        poolValue -= rewardAmount;

        require(userStake.amount > 0, "Stake is empty");

        userTotalStaked[msg.sender] -= userStake.amount;

        require(stakingToken.transfer(msg.sender, userStake.amount + rewardAmount), "Token transfer failed");
        userStake.amount = 0;
    }

    function withdrawTokens(uint256 amount) external onlyOwner {
        require(amount <= stakingToken.balanceOf(address(this)), "Insufficient tokens");
        require(stakingToken.transfer(msg.sender, amount), "Token transfer failed");
    }

    function setLockPeriod(uint256 newLockPeriod) public onlyOwner {
        lockPeriod = newLockPeriod;
    }

    function setMinStake(uint256 newMinStake) public onlyOwner {
        minStake = newMinStake;
    }

    function changeRewardRate(uint _rewardRate) public onlyOwner{
        rewardRate = _rewardRate;
    }

    function setMaxStake(uint256 newMaxStake) public onlyOwner {
        maxStake = newMaxStake;
    }
}