pragma solidity ^0.8.22;
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
contract QuantumRaffle is ReentrancyGuard {
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
    event ClaimedAdoptionBonus(uint256 indexed game_id,address indexed recipient, uint256 indexed entrant_id, uint256 cohort_id,  uint256 prize);
    event GameEntered(uint256 indexed gameId, address indexed entrant, uint256 entryAmount, uint256 entrantCount, uint256 timestamp, uint256 num_winners, uint256 prizePool, uint256 num_entries);
    constructor(uint256 _entryAmount, uint256 _deadline) 
        nonReentrant() {
            entryAmount= _entryAmount;
            deadline = _deadline;
            host = msg.sender;

    }
    receive() 
        external payable nonReentrant {
            if (isGameOver()){
                require(msg.sender==host, "Only the raffle host can start a new game");
                gameId++;
                emit GameStarted(gameId, entryAmount);
            }
            // Team 1 entrants need to deposit 10X the regular raffle price.
            uint256 entranceCost = entryAmount;
            if (entrantCount[gameId]<9) {
                entranceCost = entryAmount*10;
                require(msg.value == entranceCost, "First 10 members can only enter one at a time.");
            }
            else {
                require(msg.value >= entranceCost, "Minimum Entry Deposit Required.");
            }

            uint256 entry = msg.value;
            uint256 adoptionBonusContribution = entry / 5;
            uint256 mainPrizeContribution = entry - adoptionBonusContribution;
            prizePool[gameId] +=  mainPrizeContribution;

            uint256 num_entries = entry/entranceCost;
            uint256 num_winners;
            uint256 cohort_id;
            for (uint256 i=0; i<num_entries; i++) {
                entrantCount[gameId]++;
                entrants[gameId][entrantCount[gameId]] = msg.sender;
                num_winners = getNumWinners(gameId);
                if (num_winners==1) {
                    cohort_id = 2;
                }
                else {
                    cohort_id = num_winners;
                }
                adoptionBonusPrizePool[gameId][cohort_id] += adoptionBonusContribution/num_entries;
            }
            prizePerWinner[gameId] = prizePool[gameId]/num_winners;
            lastTimestamp[gameId] = block.timestamp;
            participantRecord[msg.sender]+=entry;
            isPowerOf10OrOne(entrantCount[gameId]); // ensures that if upper gas limit is reached, game ends and doesnt impact prize claiming.
            emit GameEntered(gameId, msg.sender, entry, entrantCount[gameId], lastTimestamp[gameId], num_winners, prizePool[gameId], num_entries);
    }
    
    function isGameOver()
        public view returns (bool isOver) {
            if (gameId==0) return true;
            return (block.timestamp>lastTimestamp[gameId]+deadline) && (entrantCount[gameId]>9);
        }
    
    function getAdoptionBonusPrizePerTeam(uint256 _gameId, uint256 _cohortId)
        public view returns (uint256) {
            return adoptionBonusPrizePool[_gameId][_cohortId]/(_cohortId-1);
    }
    
    function isQualifiedAdoptionBonus(uint256 _gameId, uint256 _entrantId, uint256 _cohortId)
        public view returns (bool) {
            uint256 num_entrants = entrantCount[_gameId];
            uint256 entrant_cohort = getNumDigits(_entrantId);
            require(!hasClaimedAdoptionBonus[_gameId][_cohortId][_entrantId], "Already claimed.");
            require(entrant_cohort<_cohortId, "Ineligible cohort.");
            require((_entrantId<=num_entrants) && (_entrantId>0), "ineligible entrant ID");
            require(gameId>=_gameId, "only active or past games.");
            require(_cohortId<getNumDigits(num_entrants), "only surpassed cohorts"); 
            return true; 
        }
    
    function _claimAdoptionBonusPrize(uint256 _gameId, uint256 _entrantId, uint256 _cohortId) 
        private {
            if(isQualifiedAdoptionBonus(_gameId, _entrantId, _cohortId)){
                uint256 team_prize = getAdoptionBonusPrizePerTeam(_gameId, _cohortId);
                uint256 d = getNumDigits(_entrantId);
                uint256 n = (10**d)- (10**(d-1));
                uint256 prize = team_prize/n;
                hasClaimedAdoptionBonus[_gameId][_cohortId][_entrantId] = true;
                address recipient = entrants[_gameId][_entrantId];
                sendEth(payable(recipient), prize);
                emit ClaimedAdoptionBonus(_gameId, recipient,  _entrantId, _cohortId, prize);
            } 
            
        }
    struct IdPair {
        uint256 cohortId;
        uint256 entrantId;
    }


    function batchClaimAdoptionBonusPrize(uint256 _gameId, IdPair[] calldata identifications) external nonReentrant {
        
        for (uint256 i = 0; i < identifications.length; i++) {
            _claimAdoptionBonusPrize(_gameId, identifications[i].entrantId, identifications[i].cohortId);
        }
    }
    function claimPrize(uint256 _gameId, uint256 _entrantId) 
        external nonReentrant {
            require(isWinner(_gameId, _entrantId), "Not a winner.");
            require(_entrantId<=entrantCount[_gameId], "ineligible entrant ID");
            require(gameId>=_gameId, "Game not finished.");
            if (gameId==_gameId) {
                require(isGameOver(), "Game not finished");
            }
            require(!hasClaimed[_gameId][_entrantId], "Can only claim once.");
            uint256 prize = prizePerWinner[_gameId];
            address winner = entrants[_gameId][_entrantId];
            leaderboard[winner]+= prize;
            hasClaimed[_gameId][_entrantId]=true;
            sendEth(payable(winner), prize);
            emit PrizeClaimed(_gameId, _entrantId, prize);
            
    }
    mapping (uint256 => bool) public hasLeftoverBeenCleared;
    function clearLeftoverAdoptionBonus(uint256 _gameId) external nonReentrant {
        require(msg.sender == host);
        require(gameId>=_gameId, "Game not finished.");
            if (gameId==_gameId) {
                require(isGameOver(), "Game not finished");
            }
        require(hasLeftoverBeenCleared[_gameId]==false);
        uint256 last_cohort = getNumWinners(_gameId);
        uint256 leftover = adoptionBonusPrizePool[_gameId][last_cohort];
        hasLeftoverBeenCleared[_gameId]=true;
        sendEth(payable(host), leftover);
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
            if (value == 0) return 1;
            uint256 digits = 0;
            while (value > 0) {
                value = value / 10;
                digits++;
            }
            return digits;

        }
    
    

}