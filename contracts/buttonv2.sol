pragma solidity ^0.8.22;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BigMoneyButton is ReentrancyGuard {
    uint256 public entryAmount;
    address public host;
    uint256 public gameId;
    uint256 public deadline = 5 minutes;
    mapping (uint256 => uint256) public lastTimestamp;
    mapping (uint256 => mapping (uint256 => address)) public entrants;
    mapping (uint256 => uint256) public entrantCount;
    mapping (uint256 => uint256) public prizePool;
    mapping (uint256 => uint256) public prizePerWinner;
    mapping (uint256 => mapping (uint256=>bool)) public hasClaimed;

    mapping (uint256 => mapping (uint256 => uint256) ) public earlyBirdPrizePool; //[gameId][cohortId]
    mapping (uint256 => mapping(uint256 => mapping (uint256 => bool))) public hasClaimedEarlyBird; // [gameId][cohortId][entrantId]

    mapping (address => uint256) public participantRecord;
    mapping (address => uint256) public leaderboard;
    

    
 
    
    event GameStarted(uint256 gameId, uint256 entryAmount);
    event PrizeClaimed(uint256 gameId, uint256 prize);
    event GameEntered(uint256 indexed gameId, address indexed entrant, uint256 entryAmount, uint256 entrantCount, uint256 timestamp, uint256 num_winners, uint256 prizePool);
    constructor(uint256 _entryAmount, uint256 _deadline) nonReentrant() {
        entryAmount= _entryAmount;
        deadline = _deadline;
        host = msg.sender;
    }
    receive() 
        external payable nonReentrant {
            require(msg.value >= entryAmount, "Minimum Entry Deposit Required.");
            if (block.timestamp>lastTimestamp[gameId]+deadline){
                gameId++;
                emit GameStarted(gameId, entryAmount);
            }
            uint256 fee = msg.value/50;
            sendEth(payable(host), fee);
            uint256 entry = msg.value-fee;
            uint256 earlyBirdEntry = entry /10;
            uint256 tensEntry = entry - earlyBirdEntry;
            prizePool[gameId] +=  tensEntry;
            entrantCount[gameId]++;
            entrants[gameId][entrantCount[gameId]] = msg.sender;
            lastTimestamp[gameId] = block.timestamp;
            uint256 num_winners = getNumWinners(gameId);
            prizePerWinner[gameId] = prizePool[gameId]/num_winners;
            earlyBirdPrizePool[gameId][num_winners] += earlyBirdEntry;
            participantRecord[msg.sender]+=entry;
            bool gas_throttle = isPowerOf10OrOne(entrantCount[gameId]); // ensures that if upper gas limit is reached, game ends and doesnt impact prize claiming.
            
            emit GameEntered(gameId, msg.sender, entry, entrantCount[gameId], lastTimestamp[gameId], num_winners, prizePool[gameId]);
    }
    function getEarlyBirdPrize(uint256 _gameId, uint256 _cohortId)
        public view returns (uint256) {
            uint256 b = _cohortId-1;
            uint256 numPerPowerGroup = (10**_cohortId)- (10**b); 
            uint256 amountPerCohort = earlyBirdPrizePool[_gameId][_cohortId]/_cohortId;
            return amountPerCohort/numPerPowerGroup;
    }
    // hasClaimedEarlyBird
    function isQualifiedEarlyBird(uint256 _gameId, uint256 _entrantId, uint256 _cohortId)
        public view returns (bool) {
            uint256 num_entrants = entrantCount[_gameId];
            
            uint256 entrant_cohort = getNumDigits(_entrantId);
            require(!hasClaimedEarlyBird[_gameId][_cohortId][_entrantId], "Already claimed.");
            require(entrant_cohort<=_cohortId, "Ineligible cohort.");
            require((_entrantId<=num_entrants) && (_entrantId>0), "ineligible entrant ID");
            require(gameId>=_gameId, "only active or past games.");
            require(_cohortId<getNumDigits(num_entrants), "only surpassed cohorts");// 
            return true;
        }
    function claimEarlyBirdPrize(uint256 _gameId, uint256 _entrantId, uint256 _cohortId)
        external nonReentrant {
            require(isQualifiedEarlyBird(_gameId, _entrantId, _cohortId));
            uint256 prize = getEarlyBirdPrize(_gameId, _cohortId);
            sendEth(payable(entrants[_gameId][_entrantId]), prize);
            hasClaimedEarlyBird[_gameId][_cohortId][_entrantId] = true;

        }
    function claimPrize(uint256 _gameId, uint256 _entrantId) 
        external nonReentrant {
            require(_entrantId<=entrantCount[_gameId], "ineligible entrant ID");
            require(gameId>=_gameId, "Game not finished.");
            if (gameId==_gameId) {
                require(block.timestamp>lastTimestamp[gameId]+deadline, "game not finished");
            }
            require(!hasClaimed[_gameId][_entrantId], "Can only claim once.");
            if (isWinner(_gameId, _entrantId)) {
                uint256 prize = prizePerWinner[_gameId];
                address winner = entrants[_gameId][_entrantId];
                sendEth(payable(winner), prize);
                leaderboard[winner]+= prize;
                hasClaimed[_gameId][_entrantId]=true;
                emit PrizeClaimed(_gameId, prize);
            }
            else {
                require(false, "Not a winner.");
            }
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
    function getNumWinners(uint256 _gameId) 
        public view returns (uint256) {
            uint256 value = entrantCount[_gameId];
            return getNumDigits(value);
    } 

    function getNumDigits(uint256 value)
        public pure returns (uint256) {
            if (value == 0) return 0;
            uint256 digits = 0;
            while (value > 0) {
                value = value / 10;
                digits++;
            }
            return digits;

        }
    function isWinner(uint256 _gameId, uint256 _entrantId) 
        public view 
        returns (bool) {
            if (_entrantId==entrantCount[_gameId]) return true;
            uint256 n = 1+ entrantCount[_gameId] - _entrantId;
            return isPowerOf10OrOne(n);

    }
    function isPowerOf10OrOne(uint256 number) 
        public pure 
        returns (bool) {
            uint256 temp = number;
            while (temp > 0) {
                if (temp % 10 != 0) { // if the number is not divisible by 10...
                    return temp == 1; // we know that it can not be a power of 10 unless it is 1.
                }
                temp = temp / 10;
            }
            return false;
}
    
    

}
