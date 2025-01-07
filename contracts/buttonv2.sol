pragma solidity ^0.8.22;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BigMoneyButtonV2 is ReentrancyGuard {
    uint256 public entryAmount;
    address public host;
    uint256 public gameId;
    uint256 public deadline;
    mapping (uint256 _gameId => uint256) public lastTimestamp;
    mapping (uint256 _gameId => mapping (uint256 _entrantId => address)) public entrants;
    mapping (uint256 _gameId => uint256) public entrantCount;
    mapping (uint256 _gameId => uint256) public prizePool;
    mapping (uint256 _gameId => uint256) public prizePerWinner;
    mapping (uint256 _gameId => mapping (uint256 _entrantId =>bool)) public hasClaimed;

    mapping (uint256 _gameId => mapping (uint256 _cohortId => uint256) ) public adoptionBonusPrizePool; //[gameId][cohortId]
    mapping (uint256 _gameId => mapping(uint256 _cohortId => mapping (uint256 _entrantId => bool))) public hasClaimedAdoptionBonus; // [gameId][cohortId][entrantId]

    mapping (address _participant => uint256) public participantRecord;
    mapping (address _participant => uint256) public leaderboard;
    
    event GameStarted(uint256 indexed gameId, uint256 entryAmount);
    event PrizeClaimed(uint256 indexed gameId, uint256 indexed entrantId, uint256 prize);
    event ClaimedAdoptionBonus(uint256 indexed game_id, uint256 indexed cohort_id, uint256 indexed entrant_id, uint256 prize);
    event GameEntered(uint256 indexed gameId, address indexed entrant, uint256 entryAmount, uint256 entrantCount, uint256 timestamp, uint256 num_winners, uint256 prizePool, uint256 num_entries);
    constructor(uint256 _entryAmount, uint256 _deadline) 
        nonReentrant() {
            entryAmount= _entryAmount;
            deadline = _deadline;
            host = msg.sender;
    }
    receive() 
        external payable nonReentrant {
            require(msg.value >= entryAmount, "Minimum Entry Deposit Required.");
            if (isGameOver()){
                gameId++;
                emit GameStarted(gameId, entryAmount);
            }
            uint256 fee = msg.value/50;
            sendEth(payable(host), fee);
            uint256 entry = msg.value-fee;
            uint256 adoptionBonusContribution = entry /10;
            uint256 mainPrizeContribution = entry - adoptionBonusContribution;
            prizePool[gameId] +=  mainPrizeContribution;
            uint256 num_entries = msg.value/entryAmount;
            uint256 num_winners;
            for (uint256 i=0; i<num_entries; i++) {
                entrantCount[gameId]++;
                entrants[gameId][entrantCount[gameId]] = msg.sender;
                num_winners = getNumWinners(gameId);
                adoptionBonusPrizePool[gameId][num_winners] += adoptionBonusContribution/num_entries;
            }
            prizePerWinner[gameId] = prizePool[gameId]/num_winners;
            lastTimestamp[gameId] = block.timestamp;
            participantRecord[msg.sender]+=msg.value;
            isPowerOf10OrOne(entrantCount[gameId]); // ensures that if upper gas limit is reached, game ends and doesnt impact prize claiming.
            emit GameEntered(gameId, msg.sender, entry, entrantCount[gameId], lastTimestamp[gameId], num_winners, prizePool[gameId], num_entries);
    }
    function isGameOver()
        public view returns (bool isOver) {
            if (gameId==0) return true;
            return (block.timestamp>lastTimestamp[gameId]+deadline) && (entrantCount[gameId]>9);
        }
    
    function getAdoptionBonusPrize(uint256 _gameId, uint256 _cohortId)
        public view returns (uint256) {
            uint256 b = _cohortId-1;
            uint256 numPerPowerGroup = (10**_cohortId)- (10**b); 
            uint256 amountPerCohort = adoptionBonusPrizePool[_gameId][_cohortId]/_cohortId;
            return amountPerCohort/numPerPowerGroup;
    }
    
    function isQualifiedAdoptionBonus(uint256 _gameId, uint256 _entrantId, uint256 _cohortId)
        public view returns (bool) {
            uint256 num_entrants = entrantCount[_gameId];
            uint256 entrant_cohort = getNumDigits(_entrantId);
            require(!hasClaimedAdoptionBonus[_gameId][_cohortId][_entrantId], "Already claimed.");
            require(entrant_cohort<=_cohortId, "Ineligible cohort.");
            require((_entrantId<=num_entrants) && (_entrantId>0), "ineligible entrant ID");
            require(gameId>=_gameId, "only active or past games.");
            require(_cohortId<getNumDigits(num_entrants), "only surpassed cohorts");// 
            return true; 
        }
    
    function claimAdoptionBonusPrize(uint256 _gameId, uint256 _entrantId, uint256 _cohortId)
        external nonReentrant {
            _claimAdoptionBonusPrize(_gameId, _entrantId, _cohortId);
        }
    function _claimAdoptionBonusPrize(uint256 _gameId, uint256 _entrantId, uint256 _cohortId) 
        private {
            require(isQualifiedAdoptionBonus(_gameId, _entrantId, _cohortId));
            uint256 prize = getAdoptionBonusPrize(_gameId, _cohortId);
            sendEth(payable(entrants[_gameId][_entrantId]), prize);
            hasClaimedAdoptionBonus[_gameId][_cohortId][_entrantId] = true;
            emit ClaimedAdoptionBonus(_gameId, _cohortId, _entrantId, prize);
        }
    function batchClaimAdoptionBonusPrize(uint256 _gameId, uint256 _entrantIdStart, uint256 _entrantIdEnd, uint256 _cohortIdStart, uint256 _cohortIdEnd)
        external nonReentrant {
            for (uint256 i=_entrantIdStart; i<=_entrantIdEnd; i++) {
                for (uint256 j = _cohortIdStart; j<=_cohortIdEnd; j ++) {
                    _claimAdoptionBonusPrize(_gameId, i, j);
                }
            }
        }
    function claimPrize(uint256 _gameId, uint256 _entrantId) 
        external nonReentrant {
            require(_entrantId<=entrantCount[_gameId], "ineligible entrant ID");
            require(gameId>=_gameId, "Game not finished.");
            if (gameId==_gameId) {
                require(isGameOver(), "game not finished");
            }
            require(!hasClaimed[_gameId][_entrantId], "Can only claim once.");
            if (isWinner(_gameId, _entrantId)) {
                uint256 prize = prizePerWinner[_gameId];
                address winner = entrants[_gameId][_entrantId];
                sendEth(payable(winner), prize);
                leaderboard[winner]+= prize;
                hasClaimed[_gameId][_entrantId]=true;
                emit PrizeClaimed(_gameId, _entrantId, prize);
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
    
    

}
