//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


/**
 * @title TokenSale
 * @dev A contract for managing token sales with different sale rounds and prices.
 */
contract TokenSale is Ownable, ReentrancyGuard{
    struct Sale {
        uint startDate;
        uint endDate;
        uint tokenPrice;
        uint soldAmount;
        uint pool;
        uint minUsdt;
        uint maxUsdt;
        mapping(address => uint) usersToken;
        address[] buyers;
    }

    IERC20 public purchaseToken;
    IERC20 public token;

    mapping(uint => Sale) public sales;

    event TokenBought(address indexed account, uint amount, uint saleType);

    /**
     * @dev Initializes the contract with the token address.
     * @param _purchaseToken The address of the ERC20 purchase token contract.
     *  @param _token The address of the ERC20 token contract.
     */
    constructor(address _purchaseToken, address _token) Ownable(msg.sender){
        require(_token != address(0), "Zero address");
        purchaseToken = IERC20(_purchaseToken);
        token = IERC20(_token);
    }

    /**
     * @notice Calculates the amount of tokens that can be bought for a given amount of purchase token.
     * @param saleNumber The sale round number.
     * @param amount The amount of purchase token.
     * @return The amount of tokens that can be bought.
     */
    function getTokenAmountForUsdt(uint saleNumber, uint amount) external view returns(uint){
        Sale storage sale = sales[saleNumber];
        uint tokensAmount = amount * 10 ** 18 / sale.tokenPrice;
        return tokensAmount;
    }

    /**
     * @notice Creates a new sale round.
     * @param saleNumber The sale round number.
     * @param startDate The start date of the sale round.
     * @param endDate The end date of the sale round.
     * @param tokenPrice The price of the token in the sale round.
     * @param pool The pool of tokens available for the sale round.
     * @param max The maximum amount of purchase token that can be spent by a single buyer.
     * @param min The minimum amount of purchase token that can be spent by a single buyer.
     */
    function createSale(uint saleNumber, uint startDate, uint endDate, uint tokenPrice, uint pool, uint max, uint min) external onlyOwner(){
        require(sales[saleNumber].pool == 0, "Sale already exist");
        Sale storage newSale = sales[saleNumber];
        require(token.transferFrom(msg.sender, address(this), pool));
        newSale.startDate = startDate;
        newSale.endDate = endDate;
        newSale.tokenPrice = tokenPrice;
        newSale.soldAmount = 0;
        newSale.pool = pool;
        newSale.minUsdt = min;
        newSale.maxUsdt = max;
    }

    /**
     * @notice Sets the token address.
     * @param _purchaseToken The address of the ERC20 purchase token contract.
     */
    function setPurchaseToken(address _purchaseToken) external onlyOwner(){
        require(_purchaseToken != address(0), "Zero address");
        purchaseToken = IERC20(_purchaseToken);
    }
    
    function setToken(address _token) external onlyOwner{
        require(_token != address(0), "Zero address");
        token = IERC20(_token);
    }

    /**
     * @notice Sets the start time for a sale round.
     * @param saleNumber The sale round number.
     * @param newTime The new start time.
     */
    function setStartTime(uint saleNumber, uint newTime) external onlyOwner(){
        Sale storage sale = sales[saleNumber];
        sale.startDate = newTime;
    }


    /**
     * @notice Sets the end time for a sale round.
     * @param saleNumber The sale round number.
     * @param newTime The new end time.
     */
    function setEndTime(uint saleNumber, uint newTime) external onlyOwner(){
        Sale storage sale = sales[saleNumber];
        sale.endDate = newTime;
    }


    /**
     * @notice Sets the price of the token for a sale round.
     * @param saleNumber The sale round number.
     * @param newPrice The new token price.
     */
    function setPrice(uint saleNumber, uint newPrice) external onlyOwner(){
        Sale storage sale = sales[saleNumber];
        sale.tokenPrice = newPrice;
    }


    /**
     * @notice Gets the token amounts of all users in a sale round.
     * @param saleNumber The sale round number.
     * @return An array of user addresses and their corresponding token amounts.
     */
    function getAllUsersToken(uint saleNumber) external view returns(address[] memory, uint[] memory){
        Sale storage sale = sales[saleNumber];
        uint[] memory tokens = new uint[](sale.buyers.length);

        for(uint i=0; i<sale.buyers.length; i++){
            tokens[i] = sale.usersToken[sale.buyers[i]];
        }
        return (sale.buyers, tokens);
    }

    /**
     * @notice Gets the token amount of a specific user in a sale round.
     * @param saleNumber The sale round number.
     * @param account The address of the user.
     * @return The token amount of the user.
     */
    function getUserTokens(uint saleNumber, address account) external view returns(uint) {
        uint amount = sales[saleNumber].usersToken[account];
        return amount;
    }

    /**
     * @notice Allows a user to buy tokens with purchase token.
     * @param saleNumber The sale round number.
     * @param amount The amount of purchase token to spend.
     */
    function buyTokens(uint saleNumber, uint amount) external nonReentrant(){
        Sale storage sale = sales[saleNumber];
        require(block.timestamp > sale.startDate, "Sale hasn't started yet");
        require(block.timestamp < sale.endDate, "Sale has been completed");
        require(amount >= sale.minUsdt, "less than the minimum");
        require(amount <=  sale.maxUsdt, "more than the maximum");
        uint remained = sale.pool - sale.soldAmount;
        uint tokensAmount = amount * 10 ** 18 / sale.tokenPrice;
        require(remained >= tokensAmount, "Not enough tokens in pool");
        require(purchaseToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        require(token.transfer(msg.sender, tokensAmount));
        sale.usersToken[msg.sender] += tokensAmount;
        sale.soldAmount += tokensAmount;
        sale.buyers.push(msg.sender);
        emit TokenBought(msg.sender, tokensAmount, saleNumber);
    }

    /**
     * @notice Transfers tokens to a specified address.
     * @param account The address to transfer tokens to.
     * @param amount The amount of purchase token to transfer.
     */
    function transferPurchaseTokens(address account, uint amount) external onlyOwner(){
        require(purchaseToken.transfer(account, amount), "Transfer failed");
    }

    function transferTokens(address account, uint amount) external onlyOwner(){
        require(token.transfer(account, amount), "Transfer failed");
    }
}