pragma solidity ^0.8.22;
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
contract QuantumRaffle is ReentrancyGuard {
    uint256 public entryAmount;
    address public host;
    uint256 public gameId;
    uint256 public deadline;
    struct IdPair {
        uint256 cohortId;
        uint256 entrantId;
    }
    
    mapping (uint256 _gameId => uint256) public lastTimestamp;
    mapping (uint256 _gameId => mapping (uint256 _entrantId => address)) public entrants;
    mapping (uint256 _gameId => uint256) public entrantCount;
    mapping (uint256 _gameId => uint256) public prizePool;
    mapping (uint256 _gameId => uint256) public prizePerWinner;
    mapping (uint256 _gameId => mapping (uint256 _entrantId =>bool)) public hasClaimed;
    mapping (uint256 _gameId => mapping (uint256 _cohortId => uint256) ) public adoptionBonusPrizePool; //[gameId][cohortId]
    mapping (uint256 _gameId => mapping(uint256 _cohortId => mapping (uint256 _entrantId => bool))) public hasClaimedAdoptionBonus; // [gameId][cohortId][entrantId]
    mapping (uint256 => bool) public hasLeftoverBeenCleared;
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
    
    /// @notice Checks if the current game has ended
    /// @dev A game is considered over if either: 1. No game has started yet (gameId == 0) 2. The deadline has passed AND there are at least 10 entrants
    /// @return isOver True if the game is over, false otherwise
    function isGameOver()
        public view returns (bool isOver) {
            if (gameId==0) return true;
            return (block.timestamp>lastTimestamp[gameId]+deadline) && (entrantCount[gameId]>9);
        }
    
    /// @notice Calculates the adoption bonus prize amount per team for a given game and cohort
    /// @dev The adoption bonus pool for each cohort is divided evenly among (_cohortId-1) teams
    /// @param _gameId The ID of the game to check
    /// @param _cohortId The cohort ID to calculate the prize for (e.g. 2 for double digits, 3 for triple digits)
    /// @return The adoption bonus prize amount per team for the specified game and cohort
    function getAdoptionBonusPrizePerTeam(uint256 _gameId, uint256 _cohortId)
        public view returns (uint256) {
            return adoptionBonusPrizePool[_gameId][_cohortId]/(_cohortId-1);
    }
    
    /// @notice Checks if an entrant is qualified to claim an adoption bonus for a given game and cohort
    /// @dev An entrant is qualified if:
    ///      1. They haven't claimed the bonus yet
    ///      2. Their entrant ID has fewer digits than the cohort ID (e.g. 2-digit ID for 3-digit cohort)
    ///      3. Their entrant ID is valid for the game
    ///      4. The game ID is valid (game must be active or completed)
    ///      5. The cohort ID is valid (must be less than total digits in entrant count)
    /// @param _gameId The ID of the game to check
    /// @param _entrantId The entrant ID to check qualification for
    /// @param _cohortId The cohort ID to check qualification for
    /// @return True if the entrant is qualified, reverts otherwise
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
    
    /// @notice Internal function to process an adoption bonus prize claim
    /// @dev Verifies eligibility via isQualifiedAdoptionBonus(), calculates prize amount, and sends ETH to recipient
    /// @param _gameId The ID of the game to claim from
    /// @param _entrantId The entrant ID claiming the bonus
    /// @param _cohortId The cohort ID being claimed (e.g. 2 for double digits, 3 for triple digits)
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
    
    /// @notice Allows batch claiming of adoption bonus prizes for multiple entrants
    /// @dev Each IdPair in the array contains a cohortId and entrantId to claim for
    /// @param _gameId The ID of the game to claim adoption bonuses from
    /// @param identifications Array of IdPair structs containing cohortId and entrantId combinations to claim
    function batchClaimAdoptionBonusPrize(uint256 _gameId, IdPair[] calldata identifications)
        external nonReentrant {
            for (uint256 i = 0; i < identifications.length; i++) {
                _claimAdoptionBonusPrize(_gameId, identifications[i].entrantId, identifications[i].cohortId);
            }
    }
    
    /// @notice Allows winners to claim their prize from a completed game
    /// @dev Verifies winner eligibility, prevents double claims, and sends ETH prize
    /// @param _gameId The ID of the game to claim from
    /// @param _entrantId The entrant ID claiming the prize
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
    
    /// @notice Allows the host to claim any unclaimed adoption bonus prizes after a game ends
    /// @dev Can only be called by the host after a game is finished and only once per game
    /// @param _gameId The ID of the completed game to clear leftover adoption bonus from
    function clearLeftoverAdoptionBonus(uint256 _gameId) 
        external nonReentrant {
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

    /// @notice Sends ETH to a specified address
    /// @dev Uses low-level call to transfer ETH, reverts if transfer fails
    /// @param _to The address to send ETH to
    /// @param amount The amount of ETH to send in wei
    function sendEth(address payable _to, uint256 amount)
        private {
            (bool sent, ) = _to.call{value: amount}("");
            require(sent, "Failed to send Ether");
    }
    
    /// @notice Allows the current host to transfer host privileges to a new address
    /// @dev Can only be called by the current host address
    /// @param _host The address of the new host
    function switchHost(address _host) 
        public nonReentrant {
            require(msg.sender == host);
            host=_host;
    }
    
    /// @notice Checks if a given entrant ID is a winner for a specific game
    /// @dev An entrant is a winner if they are either the last entrant or if their position from the end is a power of 10
    /// @param _gameId The ID of the game to check
    /// @param _entrantId The ID of the entrant to check
    /// @return bool True if the entrant is a winner, false otherwise
    function isWinner(uint256 _gameId, uint256 _entrantId)
        public view 
        returns (bool) {
            if (_entrantId==entrantCount[_gameId]) return true;
            uint256 n = 1+ entrantCount[_gameId] - _entrantId;
            return isPowerOf10OrOne(n);
    }
    /// @notice Checks if a number is a power of 10 or 1
    /// @dev Used internally to determine if an entrant position qualifies for a prize
    /// @param number The number to check
    /// @return bool True if the number is a power of 10 or 1, false otherwise
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
    /// @notice Gets the number of winners for a given game ID
    /// @dev Calculates winners based on the number of digits in the total entrant count
    /// @param _gameId The ID of the game to check
    /// @return uint256 The number of winners for the specified game
    function getNumWinners(uint256 _gameId) 
        public view returns (uint256) {
            uint256 value = entrantCount[_gameId];
            return getNumDigits(value);
    } 
    /// @notice Gets the number of digits in a given number
    /// @dev Used internally to calculate number of winners based on entrant count
    /// @param value The number to count digits for
    /// @return uint256 The number of digits in the input value
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