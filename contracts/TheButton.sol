// SPDX-License-Identifier: None
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
pragma solidity ^0.8.22;

contract TheButton is ReentrancyGuard {
    uint256 public gameId;
    uint256 public deadline = 5 minutes;
    mapping (uint256 => uint256) public lastTimestamp;
    mapping (uint256 =>address) public latestEntrant;
    mapping (uint256=>uint256) public entries;
    mapping (uint256=>bool) public hasClaimed;
    mapping (address =>uint256) public participantRecord;
    mapping (address => uint256) public leaderboard;
    uint256 public entryAmount;
    address public host;
    uint256 public scheduledNewEntryAmountValue;
    uint256 public scheduledChangeActive;
    constructor(uint256 _entryAmount) nonReentrant() {
        entryAmount=_entryAmount;
        host = msg.sender;
    }
    receive() 
        external payable {
            require(msg.value >= entryAmount, "Minimum Entry Deposit Required.");
            if (block.timestamp>lastTimestamp[gameId]+deadline){
            gameId++;
            }
            entries[gameId] += msg.value;
            participantRecord[msg.sender]+=msg.value;
            lastTimestamp[gameId] = block.timestamp;
            latestEntrant[gameId]=msg.sender;
    }
    
    function claimPrize(uint256 _gameId) 
        external nonReentrant {
            require(gameId>=_gameId, "Game not finished.");
            if (gameId==_gameId) {
                require(block.timestamp>lastTimestamp[gameId]+deadline, "game not finished");
            }
            require(latestEntrant[_gameId]==msg.sender, "Only winner can run");
            require(!hasClaimed[_gameId], "Can only claim once.");
            uint256 fee = entries[_gameId]/20;
            uint256 prize = entries[_gameId]-fee;
            sendEth(payable(host), fee);
            sendEth(payable(msg.sender), prize);
            leaderboard[msg.sender]+= prize;
            hasClaimed[_gameId]=true;
    }
    function sendEth(address payable _to, uint256 amount) 
        private {
            (bool sent, ) = _to.call{value: amount}("");
            require(sent, "Failed to send Ether");
    }
    function switchHost(address _host) 
        public nonReentrant {
            require(msg.sender == host);
            host=_host;
    }
    function scheduleEntryAmountChange(uint256 newValue) external {
        require(msg.sender==host, "Only host can do this");
        scheduledChangeActive = gameId + 1;
        scheduledNewEntryAmountValue=newValue;
    }
    function activateScheduledChange() external {
        require (scheduledChangeActive > 0);
        require(gameId>=scheduledChangeActive);
        entryAmount = scheduledNewEntryAmountValue;
        scheduledChangeActive = 0;
        scheduledNewEntryAmountValue = 0;
    }

}