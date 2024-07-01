// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Vesting contract.
 * @dev A contract for vesting ERC20 tokens with multiple vesting schedules.
 */
contract Vesting is Ownable, ReentrancyGuard{

    /**
     * @dev Sets the token that will be vested.
     * @param _vestingToken The address of the ERC20 token contract.
     * @param _initialAddress The owner account.
     */
    constructor(address _vestingToken, address _initialAddress) Ownable(_initialAddress){
        require(_vestingToken != address(0), "Zero address");
        token = IERC20(_vestingToken);
    }

    IERC20 public token;

    struct VestingSchedule {
        uint totalAmount;
        uint amountReleased;
        uint claimedPeriodAmount;
    }

    struct VestingCreation {
        uint pool;
        uint beneficiariesAmount;
        address[] beneficiariesAdresses;
        uint cliffPeriod;
        uint vestingPeriod;
        uint tge;
        uint startTimestamp;
        mapping(address => VestingSchedule) beneficiaries;
    }

    uint public unlockPeriod = 30 days;

    event BeneficiaryAdded(address indexed user, uint indexed vestingId, VestingSchedule schedule);
    event BeneficiaryBatchAdded(address[] indexed users, uint[] totalAmounts, uint indexed vestingId);
    event Claimed(address indexed user, uint indexed vestingId, uint amount);
    event UnlockPeriodUpdated(uint newPeriod);
    event StartTimeUpdated(uint indexed vestingId, uint newTime);

    mapping(uint => VestingCreation) public vestingInfo;
    
    /**
     * @notice Sets the token address for the vesting contract.
     * @dev Only the owner can call this function.
     * @param _token The address of the ERC20 token contract.
     */
    function setTokenAddress(address _token) external onlyOwner {
        require(address(_token) != address(0), "Token address cannot be zero");
        token = IERC20(_token);
    }

    /**
     * @notice Sets the unlock period for vesting.
     * @dev Only the owner can call this function.
     * @param newPeriod The new unlock period in seconds.
     */
    function setUnlockPeriod(uint newPeriod) external onlyOwner(){
        require(unlockPeriod > 0, "Period can not be zero");
        unlockPeriod = newPeriod;
        emit UnlockPeriodUpdated(newPeriod);
    }

    function getBeneficiaryInfo(uint _vestingId, address _beneficiary) public view returns(VestingSchedule memory){
        return vestingInfo[_vestingId].beneficiaries[_beneficiary];
    }

    function getBeneficiaries(uint _vestingId) public view returns(address[] memory){
        return vestingInfo[_vestingId].beneficiariesAdresses;
    } 

    /**
     * @notice Sets the start time for a vesting schedule.
     * @dev Only the owner can call this function.
     * @param _vestingId The ID of the vesting.
     * @param _timestamp The start timestamp.
     */
    function setStartTime(uint _vestingId, uint _timestamp) external onlyOwner {
        require(_timestamp >= block.timestamp, "Start time cannot be in the past");
        vestingInfo[_vestingId].startTimestamp = _timestamp;
        emit StartTimeUpdated(_vestingId, _timestamp);
    }
    /**
     * @notice Gets the next claimable timestamp for a user.
     * @param _vestingId The ID of the vesting.
     * @return The next claimable timestamp.
     */
    function getNextClaimTimestamp(uint _vestingId) external view returns(uint){
        uint startTimestamp = vestingInfo[_vestingId].startTimestamp;
        require(block.timestamp >= startTimestamp, "Vesting hasn't started yet");
        if(startTimestamp == 0){
            return 0;
        }else{
            if(block.timestamp >= (startTimestamp + vestingInfo[_vestingId].cliffPeriod)){
                uint periodAmount = (block.timestamp - (startTimestamp + vestingInfo[_vestingId].cliffPeriod)) / unlockPeriod;
                return (startTimestamp + vestingInfo[_vestingId].cliffPeriod) + ((periodAmount + 1)*unlockPeriod);
            }else{
                return (startTimestamp + vestingInfo[_vestingId].cliffPeriod) + unlockPeriod;
            }
        }
    }

    /**
     * @notice Adds a new specific vesting schedule.
     * @dev Only the owner can call this function.
     * @param _vestingId The ID of the vesting.
     * @param _pool The total amount of tokens to be vested.
     * @param _cliffPeriod The cliff period of the vesting.
     * @param _vestingPeriod The vesting period of the vesting.
     * @param _tge The token generation event percentage of the vesting.
     */

    function createVesting(
        uint _vestingId, 
        uint _pool,
        uint _cliffPeriod,
        uint _vestingPeriod, 
        uint _tge,
        uint _startTimeStamp
    ) public  onlyOwner {
        VestingCreation storage newVesting = vestingInfo[_vestingId];
        newVesting.pool = _pool;
        newVesting.beneficiariesAmount = 0;
        newVesting.cliffPeriod = _cliffPeriod;
        newVesting.vestingPeriod = _vestingPeriod;
        newVesting.tge = _tge;
        newVesting.startTimestamp = _startTimeStamp;

    }

    /**
     * @notice Adds a new beneficiary to a specific   vesting schedule.
     * @dev Only the owner can call this function.
     * @param _beneficiary The address of the beneficiary.
     * @param _totalAmount The total amount of tokens to be vested.
     * @param _vestingId The ID of the vesting.
     */
    function addBeneficiary(
        address _beneficiary,
        uint256 _totalAmount,
        uint _vestingId
    ) public onlyOwner{
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");
        require(_totalAmount > 0, "Total amount must be greater than zero");
        require(vestingInfo[_vestingId].pool >= _totalAmount, "No tokens in pool");

        vestingInfo[_vestingId].beneficiaries[_beneficiary] = VestingSchedule({
        totalAmount: _totalAmount,
        amountReleased:0,
        claimedPeriodAmount: 0
        });
        vestingInfo[_vestingId].beneficiariesAdresses.push(_beneficiary);
        vestingInfo[_vestingId].pool -= _totalAmount;
        vestingInfo[_vestingId].beneficiariesAmount++;
    }
    /**
     * @notice Adds multiple beneficiaries to a specific   vesting schedule.
     * @dev Only the owner can call this function.
     * @param _beneficiaries The addresses of the beneficiaries.
     * @param _totalAmounts The total amounts of tokens to be vested.
     * @param _vestingId The ID of the vesting.
     */
    function addBatchBeneficiary(
        address[] calldata _beneficiaries,
        uint256[] calldata _totalAmounts,
        uint256 _vestingId
    ) external onlyOwner{
        require(_beneficiaries.length == _totalAmounts.length, "Length should be equal");
        for(uint i=0; i<_beneficiaries.length; i++){
            addBeneficiary(_beneficiaries[i], _totalAmounts[i], _vestingId);
        }
        emit BeneficiaryBatchAdded(_beneficiaries, _totalAmounts, _vestingId);
    }

    /**
     * @notice Gets the available amount to claim and the period amount for a beneficiary.
     * @param _beneficiary The address of the beneficiary.
     * @param _vestingId The ID of the vesting.
     * @return The available amount to claim and the period amount.
     */
    function availableToClaim(address _beneficiary, uint _vestingId) public view returns(uint, uint){
        VestingSchedule memory beneficiary = vestingInfo[_vestingId].beneficiaries[_beneficiary];
        uint startTimestamp = vestingInfo[_vestingId].startTimestamp;
        require(startTimestamp != 0 && startTimestamp <= block.timestamp, "Vesting hasn't started yet");

        uint amount = beneficiary.totalAmount;
        uint tgeAmount = beneficiary.totalAmount * vestingInfo[_vestingId].tge / 100;
        uint withoutTge = amount - tgeAmount;

        uint cliffEndTime = startTimestamp + vestingInfo[_vestingId].cliffPeriod;
        uint vestingEndTime = startTimestamp +  vestingInfo[_vestingId].vestingPeriod;

        
        if(amount <= beneficiary.amountReleased){
            return (0, beneficiary.claimedPeriodAmount);
        }

        if(cliffEndTime <= block.timestamp){
            if(vestingEndTime <= block.timestamp){
                return (amount - beneficiary.amountReleased, (vestingEndTime - cliffEndTime) / unlockPeriod);
            }else{
                uint periodAmount = (block.timestamp - cliffEndTime) / unlockPeriod;
                return (withoutTge * ((periodAmount - beneficiary.claimedPeriodAmount) * unlockPeriod) / vestingInfo[_vestingId].vestingPeriod, periodAmount);
            }
        }else{
            return (tgeAmount - beneficiary.amountReleased, 0);
        }
    }

    /**
     * @notice Claims the available vested tokens for the sender.
     * @dev Only callable by the beneficiary.
     * @param _vestingId The ID of the vesting.
     */
    function claim(uint _vestingId) external nonReentrant(){
        (uint availableAmount, uint period) = availableToClaim(msg.sender, _vestingId);
        require(availableAmount > 0, "There are no tokens available");
        VestingSchedule storage beneficiary = vestingInfo[_vestingId].beneficiaries[msg.sender];
        beneficiary.amountReleased += availableAmount;
        beneficiary.claimedPeriodAmount = period;
        require(token.transfer(msg.sender, availableAmount), "Transfer failed");
        emit Claimed(msg.sender, _vestingId, availableAmount);
    }
    /**
     * @notice Trasnfer tokens
     * @dev Only callable by the owner.
     * @param account address of the account where to tokens will be transferred.
     * @param amount amount tokens that will  be transferred.
     */
    function transferTokens(address account, uint amount) external onlyOwner(){
        require(token.transfer(account, amount), "Transfer failed");
    }
}