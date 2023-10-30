// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./strutils.sol";

contract Lotto4DToken is IERC20, Ownable {
    using strutils for *; // Enable string utilities
    string public name = "Lotto 4D Token";
    string public symbol = "L4D";
    uint8 public decimals = 9;
    
    // Total supply of tokens
    uint256 private _totalSupply;
    
    // Mapping of user addresses to their token balances
    mapping(address => uint256) private _balances;
    
    // Mapping of allowances for token transfers
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 public minimumBet =   100000000; // 0.1 L4D
    uint256 public maximumBet = 250000000000; // 250 L4D
    uint256 public drawTime = 86400; // 24 hour in seconds
    uint256 public lastDrawTimestamp;
    uint256 public lastDrawResult;


    // List to store all draw results
    struct DrawResult {
        uint256 result;
        uint256 timestamp;
    }
    DrawResult[] public drawResults;

    // List to store total bets and amount placed

    uint256 public betTotal;
    uint256 public amountTotal;
 
 
    // List to store all winners
    struct WinnerLists {
        address addressWin;
        uint256 drawNum;
        uint256 betAmount;
        uint256 winAmount;
        uint8 digit;
    }
    WinnerLists[] public winnerLists;

    constructor(uint256 initialSupply) Ownable(msg.sender) {
        _totalSupply = initialSupply * 10 ** uint256(decimals);
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
        lastDrawTimestamp = block.timestamp;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] - subtractedValue);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");
        require(_balances[sender] >= amount, "Insufficient balance");
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    // Function for onlyOwner to withdraw contract balance
    function withdrawL4D(uint256 amount) external onlyOwner {
        require(_balances[address(this)] >= amount, "Insufficient contract balance");

       // Transfer L4D tokens from the contract to the owner
        _transfer(address(this), owner(), amount);
    }
       
    struct Bet {
        address player;
        uint256 amount;
        uint256 guess;
   	uint8 numDigit;
    }
    
    Bet[] public bets;

    event BetPlaced(address indexed player, uint256 amount, uint16 guess, uint8 numDigit);
    event Draw(uint256 result);
    event Winner(address indexed player, uint256 amount);

    modifier onlyBeforeDrawTime() {
        require(block.timestamp < lastDrawTimestamp + drawTime, "Draw time has passed");
        _;
    }

    modifier onlyAfterDrawTime() {
        require(block.timestamp >= lastDrawTimestamp + drawTime, "Draw time has not passed yet");
        _;
    }

    function placeBatchBetsWithToken(uint16[] memory guesses, uint256[] memory amounts, uint8[] memory numDigit) external onlyBeforeDrawTime {
        require(guesses.length > 0 && guesses.length == amounts.length, "Invalid batch bet data");
        uint256 totalBatchAmount = 0;
        uint256 totalBatchPlaced = 0;

        for (uint256 i = 0; i < guesses.length; i++) {
            require(amounts[i] >= minimumBet && amounts[i] <= maximumBet, "Invalid bet amount");
            require(_balances[msg.sender] >= amounts[i], "Insufficient token balance");

            // Transfer the tokens to smart contract
            _transfer(msg.sender, address(this), amounts[i]);
            bets.push(Bet(msg.sender, amounts[i], guesses[i], numDigit[i]));
            totalBatchAmount += amounts[i];
            totalBatchPlaced += 1;
            emit BetPlaced(msg.sender, amounts[i], guesses[i], numDigit[i]);

        }
        betTotal += totalBatchPlaced;
        amountTotal += totalBatchAmount;
        require(totalBatchAmount <= _balances[msg.sender], "Insufficient token balance");
    }

    function setMinimumBet(uint256 _minimumBet) external onlyOwner {
        minimumBet = _minimumBet;
    }

    function setMaximumBet(uint256 _maximumBet) external onlyOwner {
        maximumBet = _maximumBet;
    }

    function setDrawTime(uint256 _drawTime) external onlyOwner {
        drawTime = _drawTime;
    }
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b)));
    }
        function toUint(string memory s) public pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < bytes(s).length; i++) {
            result = result * 10 + (uint256(uint8(bytes(s)[i]) - 48));
        }
        return result;
    }
    function draw() external onlyAfterDrawTime {
        // Generate a random 4-digit result (0-9999)
        uint256 result = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 10000;

        // Format the result with leading zeros
        string memory formattedResult = uint256(result).toString(4); // Format as a 4-digit number

        lastDrawResult = toUint(formattedResult); // Convert back to uint256
        emit Draw(lastDrawResult);

        // Store the draw result in the list
        drawResults.push(DrawResult(lastDrawResult, block.timestamp));
    	uint256 payout;
        for (uint256 i = 0; i < bets.length; i++) {
            Bet memory bet = bets[i];

    	if (bet.numDigit == 4 && bet.guess == lastDrawResult) {

    		payout = bet.amount * 4000;
            require(_balances[address(this)] >= payout, "Insufficient contract balance");
            _balances[bet.player] += payout;
            _balances[address(this)] -= payout;  // Adjust the smart contract balance
           
            winnerLists.push(WinnerLists(bet.player, lastDrawResult, bet.amount, payout, bet.numDigit));

    	} else if (bet.numDigit == 3 && bet.guess % 1000 == lastDrawResult % 1000) {
	
    		payout = bet.amount * 350;
            require(_balances[address(this)] >= payout, "Insufficient contract balance");
            _balances[bet.player] += payout;
            _balances[address(this)] -= payout;  // Adjust the smart contract balance
           
            winnerLists.push(WinnerLists(bet.player, lastDrawResult, bet.amount, payout, bet.numDigit));

    	} else if (bet.numDigit == 2 && bet.guess % 100 == lastDrawResult % 100) {

    		payout = bet.amount * 70;
            require(_balances[address(this)] >= payout, "Insufficient contract balance");
            _balances[bet.player] += payout;
            _balances[address(this)] -= payout;  // Adjust the smart contract balance
           
            winnerLists.push(WinnerLists(bet.player, lastDrawResult, bet.amount, payout, bet.numDigit));
    	}    
        }

    // Reset bets after the draw
    for (uint256 i = 0; i < bets.length; i++) {
        delete bets[i];
    }
    while (bets.length > 0) {
        bets.pop();
    }
        lastDrawTimestamp = block.timestamp;
    }
        

    function getBetHistory() external view returns (Bet[] memory) {
        Bet[] memory formattedBets = new Bet[](bets.length);

        for (uint256 i = 0; i < bets.length; i++) {
           Bet memory originalBet = bets[i];
            string memory formattedGuess = uint256(originalBet.guess).toString(4);

           formattedBets[i] = Bet(originalBet.player, originalBet.amount, toUint(formattedGuess), originalBet.numDigit);
        }
        return formattedBets;
    }


    // View function to get the last draw timestamp
    function getLastDrawTime() external view returns (uint256) {
        return lastDrawTimestamp;
    }

    // View function to get the last draw result
    function getLastDrawResult() external view returns (uint256) {
        return lastDrawResult;
    }

    // Function to view all draw results
    function getAllDrawResults() external view returns (DrawResult[] memory) {
        return drawResults;
    }

    // Function to view total bets placed
 
    function getTotalBets() external view returns (uint256) {
        return betTotal;
    }
    function getTotalAmounts() external view returns (uint256) {
        return amountTotal;
    }
    // Function to view all winners
    function getWinnerLists() external view returns (WinnerLists[] memory) {
        return winnerLists;
    }

    // Function to view the contract's balance
    function getContractBalance() external view returns (uint256) {
        return _balances[address(this)];
    }


}
