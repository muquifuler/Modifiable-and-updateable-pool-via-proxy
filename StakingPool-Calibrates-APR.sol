// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingPool_Calibrates_APR is Ownable
    // Pool without time limit in which the developer can calibrate the APR by choosing in how many years the liquidity of the pool will be divided
{

    /*
    *   @FEE            -> The commission charged for deposit
    *   @SECONDS_A_YEAR -> The seconds in a year
    */
    uint8 private constant FEE = 2;
    uint32 private constant SECONDS_A_YEAR = 31536000;

    /*
    *   @pool               -> where the reward money is stored, used to accumulate commissions and calculate the APR
    *   @allBalances        -> the sum of all the balances of all the users, is used to get the APR
    *   @minimumLiquidity   -> Minimum liquidity that the pool must have (It is not possible for it to have a value greater than 8041680000, that is why it is uint64)
    *   @years_             -> Number of years in which the benefits will be divided
    */
    uint256 private pool;
    uint256 private allBalances;
    uint64 private minimumLiquidity;
    uint8 private years_;

    struct User{
        uint256 balance;
        uint256 profit;
        uint256 time;
    }

    mapping(address => User) private users;

    event invest_(address indexed sender, uint256 indexed value);
    event withdraw_(address indexed sender, uint256 indexed value);

    /*
    *   @years_ The higher the number of years, the lower the APR.
    *
    *   Explanation: If you put for example 3 years, you are telling him to distribute the money from the pool gradually over 3 years.
    *   Clarification: The time is continuously recalculated, therefore it is an infinite pool of time.
    *
    *   WARNING: 1 year costs 31536000 gas, 2 twice as much and so on, the maximum being 255
    */
    constructor(uint8 newYears) payable
    {
        require(newYears <= 255, "Too many years");
        require(msg.value >= SECONDS_A_YEAR*newYears, "There is not enough gas to start the pool");
        pool = msg.value;
        minimumLiquidity = SECONDS_A_YEAR*newYears;
        years_ = newYears;
    }

    function invest() external payable
    {
        // When changing the amount, the last profit is added so that it does not intervene with the new amount
        if(users[msg.sender].balance != 0) users[msg.sender].profit = getUserProfit();

        uint256 fee_ = (msg.value/100)*FEE;
        pool += fee_;
        users[msg.sender].balance += msg.value-fee_;
        users[msg.sender].time = block.timestamp;
        allBalances +=  msg.value-fee_;
        emit invest_(msg.sender, users[msg.sender].balance);
    }

    /*
    *   It is done this way by setting the values ​​to 0 before making the transfer to avoid the double spend attack
    *   @user Address to which the money is withdrawn
    */
    function withdraw(address payable user) external
    {
        require((pool-users[msg.sender].balance) > minimumLiquidity, "There are not enough funds in the pool");
        require(user == msg.sender, "Your are not the user");
        uint256 balance = users[msg.sender].balance;
        users[msg.sender].balance = 0;
        allBalances -= balance;
        emit withdraw_(msg.sender, balance);
        user.transfer(balance);
    }

    /*
    *   pool/years_     -> Annual money available to distribute
    *   /allBalances    -> Annual money divided by total user money
    *   *100            -> The result is translated into a percentage
    */
    function getApr() external view returns (uint256)
    {
        require(allBalances > 0 && pool > 2, "There is no money in the pool");
        if(((pool/years_)*100)/allBalances == 0) return 0; 
        return ((pool/years_)*100)/allBalances;
    }
    
    /*
    *   @return Time the user has spent since the last investment
    */
    function getTime() private view returns (uint256)
    {
        return block.timestamp - users[msg.sender].time;
    }

    /*
    *   @return Money available to earn
    */
    function getPoolAmount() external view returns (uint256)
    {
        return pool;
    }

    /*
    *   @return User Balance
    */
    function getUserBalance() public view returns (uint256)
    {
        return users[msg.sender].balance;
    }

    /*
    *   @moneyPerSecond         -> Money per second
    *   @percentageOfTotalUser  -> Rule of years_ to see the percentage of the user in the balance sheet
    *   @return                 -> The total money multiplied by the accumulated time of the user, 
    *                              divided by 100 and multiplied by the percentage of the user plus 
    *                              the accumulated profit of the user.
    */
    function getUserProfit() public view returns (uint256)
    {
        require(users[msg.sender].balance > 0 && (pool/years_) > SECONDS_A_YEAR, "There is no money in the pool");
        uint256 moneyPerSecond = (pool/years_)/SECONDS_A_YEAR;
        uint256 percentageOfTotalUser = 100*getUserBalance()/allBalances;
        return (((moneyPerSecond*getTime())/100)*percentageOfTotalUser)+users[msg.sender].profit;
    }

    /*
    *   @return How much is left for the pool to be full
    */
    function injectMoney() external payable
    {
        pool += msg.value;
    }

}
