// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import './WordSelector.sol';

contract wordanaMain is RrpRequesterV0, wordSelector{

    enum GameStatus{
        InProgress,
        Canceled,
        Concluded,
        Pending
    }

    enum gamePrizeStatus{
        notAvailable,
        withdrawnByWinner,
        withdrawnByOwner
    }

    struct GameInstance {
        address player1; // player1 address is the unique identifier for each game instance
        address player2;
        uint256 entryPrice; // the amount of wordana tokens each player has to stake to enter the game
        address winner;
        GameStatus status;
        uint256 wordToGuess;
        uint256 player1GuessIndex;
        uint256 player2GuessIndex;
        bool player1done;
        bool player2done;
        bool isDraw;
        bool prizeCollected;
    }

    address public owner;
    address wordanaTokenAddress;
    IERC20 wordanaToken;

    string wordOfTheDay;

    string private appKey;  // the key used by the frontend app to access specific functions

    uint256 public allowedNumberOfGuesses = 6;

    uint256[] randomNumArray;
    uint256 requestIndex = 0;

    // params for random number generator (API3 QRNG)
    address public airnode;
    bytes32 public endpointIdUint256;
    bytes32 public endpointIdUint256Array;
    address public sponsorWallet;
    mapping (bytes32 => bool) public  expectingRequestWithIdToBeFulfilled;
    mapping (bytes32 => address) public  RequestIdsForGameInstance;

    // single player game params
    uint256 public tokensToEarn;
    uint256 public randomNum;

    mapping (address => uint256) public XP;
    mapping (address => string) wordOfTheDayWinners;

    event wordSelected(bytes32 indexed requestId, address player1Address);
    event player2HasEntered(address indexed player1Address, address indexed player2Address, uint256 indexed wordToGuess);
    event gameWon(address indexed winnerAddress, address indexed player1Address);
    event playerScoreChanged(address indexed player1Address);
    event gameDrawn(address indexed player1Address);
    event randomNumberProvided(uint256 indexed randomNumber);
    event singlePlayerRewardCollected(address indexed playerAddress);
    event multiplayerRewardClaimed(address indexed playerAddress);
    event wordOfTheDayReturned(string indexed wordOfTheDay);
    event wordOfTheDayRewardCollected(address indexed winner);
    event drawRefund(address indexed player1Address);

    mapping(address=>GameInstance) private  games;  // a player can create only one game instance at a time
    GameInstance newGame;
    GameInstance gameToEnter;

    constructor(address _tokenAddress, address _airnodeRrp, string memory _appkey, uint256 _tokensToEarn) RrpRequesterV0(_airnodeRrp){
        owner = msg.sender;
        wordanaToken = IERC20(_tokenAddress);
        appKey = _appkey;
        tokensToEarn = _tokensToEarn * 1000000000000000000 ;
        wordanaTokenAddress = _tokenAddress;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'you are not the owner of this contract');
        _;
    }

    modifier onlyApp(string memory _appkey) {
        require(keccak256(abi.encodePacked(_appkey)) == keccak256(abi.encodePacked(appKey)), "App key is invalid");
        _;
    }

    function setRandomNumberRequestParameters(address _airnode,
     bytes32 _endpointIdUint256, bytes32 _endpointIdUint256Array,
     address _sponsorWallet) external onlyOwner {
        airnode = _airnode;
        endpointIdUint256 = _endpointIdUint256;
        sponsorWallet = _sponsorWallet;
        endpointIdUint256Array = _endpointIdUint256Array;
    }

    function createGameInstance (address _player2, uint256 _entryPrice) public {
        require(_player2 != address(0), "Invalid player address");
        require(_player2 != msg.sender, "You cannot invite yourself to a game");
        // player1 transfers the entry price in wordana tokens to contract address then
        // setup new game instance
        newGame.player1 = msg.sender;
        newGame.player2 = _player2;
        newGame.entryPrice = _entryPrice;
        newGame.status = GameStatus.Pending;
        newGame.player1done = false;
        newGame.player2done = false;
        games[msg.sender] = newGame;
        stakeCoins(msg.sender, wordanaTokenAddress, _entryPrice);
        selectWord(msg.sender);
        return ;
    }

    // this function helps player2 enter the game he/she has been invited to
    function enterGame (address _player1) public{
        require(games[_player1].status != GameStatus.Concluded, "this game has been concluded");
        require(games[_player1].player2 == msg.sender, "You were not invited to this game");

        // deposit your own price.
        stakeCoins(msg.sender, wordanaTokenAddress, gameToEnter.entryPrice);
        // update the game to be in progress
        games[_player1].status = GameStatus.InProgress;
        emit player2HasEntered(_player1, msg.sender, games[_player1].wordToGuess);
    }

    function getGameInstance () public view returns (uint256){
        return  games[msg.sender].wordToGuess;
    }

     function stakeCoins(
        address playerAddress,
        address tokenAddress,
        uint256 requiredAmount
    ) public returns (bool) {
        // Validate input parameters:
        require(playerAddress != address(0), "Invalid player address");
        require(tokenAddress != address(0), "Invalid token address");

        // Ensure sufficient token balance:
        IERC20 token = IERC20(tokenAddress);
        require(
            token.allowance(playerAddress, address(this)) >= requiredAmount,
            "Insufficient token allowance"
        );

        require(token.balanceOf(playerAddress) >= requiredAmount, "Insufficient balance");

        //  Transfer tokens from player to contract:
        token.transferFrom(playerAddress, address(this), requiredAmount);

        return true;
    }

    function updateTokenAddress (address _newTokenAddress) public onlyOwner returns (bool){
        wordanaTokenAddress = _newTokenAddress;
        return true;
    }

    function changeOwner (address _newOwner) public onlyOwner {
        require(_newOwner != owner, "this new owner is the same as the old one");
        owner = _newOwner;
    }

    function selectWord(address currentPlayer1) private {
        uint256 wordIndex = (randomNumArray[requestIndex] % (260 - 0 + 1)) + 0;
        games[currentPlayer1].wordToGuess = wordIndex;
        if (requestIndex < 199){
            requestIndex = requestIndex + 1;
        } else{
            requestIndex = 0;
        }
    }

    // record score 
    function recordGame(address player1Address, uint256 _guessIndex, string memory _appkey) public onlyApp(_appkey){
        require(games[player1Address].status == GameStatus.InProgress, "this game is no longer in progress");
        if (msg.sender != player1Address){
            require(msg.sender == games[player1Address].player2, "you are not a participant in the game");
            games[player1Address].player2GuessIndex = _guessIndex;
            games[player1Address].player2done = true;
            if (games[player1Address].player1done){
                concludeGame(player1Address);
            }
        } else{
            games[player1Address].player1GuessIndex = _guessIndex;
            games[player1Address].player1done = true;
            if (games[player1Address].player2done){
                concludeGame(player1Address);
            }
        }
        emit playerScoreChanged(player1Address);
    }
    
    function concludeGame (address player1Address) private {
        games[player1Address].status = GameStatus.Concluded;
        // determine winner
        if (games[player1Address].player1GuessIndex < games[player1Address].player2GuessIndex){
            games[player1Address].winner = games[player1Address].player1;
            uint256 player1XP =  XP[games[player1Address].player1];
            XP[games[player1Address].player1] = player1XP + 10;
            uint256 player2XP =  XP[games[player1Address].player2];
            XP[games[player1Address].player2] = player2XP + 3;
            emit gameWon(games[player1Address].player1, player1Address);
        } else if (games[player1Address].player1GuessIndex > games[player1Address].player2GuessIndex){
            games[player1Address].winner = games[player1Address].player2;
            uint256 player1XP =  XP[games[player1Address].player1];
            XP[games[player1Address].player1] = player1XP + 3;
            uint256 player2XP =  XP[games[player1Address].player2];
            XP[games[player1Address].player2] = player2XP + 10;
            emit gameWon(games[player1Address].player2, player1Address);
        } else {
            games[player1Address].isDraw = true;
            emit gameDrawn(player1Address);
        }
    }

    function winnerClaimReward (address player1Address) public {
        require(!games[player1Address].prizeCollected, "Prize has already been collected");
        require(games[player1Address].winner == msg.sender, "you did not win this game");
        wordanaToken.transfer(msg.sender, games[player1Address].entryPrice * 2);
        games[player1Address].prizeCollected = true;
        emit multiplayerRewardClaimed(msg.sender);
    }

    function refundForDraw (address player1Address) public {
        // refund both players
        require(!games[player1Address].prizeCollected, "Prize has already been collected");
        require(games[player1Address].isDraw, "the game is not a draw");
        uint256 tokensEarned = games[player1Address].entryPrice;
        wordanaToken.transfer(games[player1Address].player1, tokensEarned);
        wordanaToken.transfer(games[player1Address].player2, tokensEarned);
        games[player1Address].prizeCollected = true;
        // add XP
        uint256 player1XP =  XP[games[player1Address].player1];
        XP[games[player1Address].player1] = player1XP + 5;
        uint256 player2XP =  XP[games[player1Address].player2];
        XP[games[player1Address].player2] = player2XP + 5;
        emit drawRefund(player1Address);
    }

    function getWinner (address player1Address) public view returns(address){
        return games[player1Address].winner;
    }

    function getWordForSinglePlayer(string memory _appkey) public onlyApp(_appkey) {
        uint256 numToReturn = (randomNumArray[requestIndex] % (260 - 0 + 1)) + 0;
        if (requestIndex < 199){
            requestIndex = requestIndex + 1;
        } else{
            requestIndex = 0;
        }
        emit randomNumberProvided(numToReturn);
    }

    function singlePlayerCollectReward(string memory _appkey) public onlyApp(_appkey) {
        uint256 tokensEarned = tokensToEarn;
        wordanaToken.transfer(msg.sender, tokensEarned);
        // add XP
        uint256 currentXP =  XP[msg.sender];
        XP[msg.sender] = currentXP + 3;
        emit singlePlayerRewardCollected(msg.sender);
    }

    function requestRandomNumbers(uint256 size) public  onlyOwner {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256Array,
            address(this),
            sponsorWallet,
            address(this),
            this.storeRandomNumberArray.selector,
            abi.encode(bytes32("1u"), bytes32("size"), size)
        );

        expectingRequestWithIdToBeFulfilled[requestId] = true;
    }

    function storeRandomNumberArray(bytes32 requestId, bytes calldata data) external onlyAirnodeRrp{
        require(expectingRequestWithIdToBeFulfilled[requestId], "Request id unknown");
        expectingRequestWithIdToBeFulfilled[requestId] = false;

        randomNumArray = abi.decode(data, (uint256[]));
    }

    function setWordOfTheDay() public onlyOwner{
        uint256 wordIndex = (randomNumArray[requestIndex] % (260 - 0 + 1)) + 0;
        wordOfTheDay = getWord(wordIndex);
        if (requestIndex < 199){
            requestIndex = requestIndex + 1;
        } else{
            requestIndex = 0;
        }
    }

    function collectRewardForTheDay(string memory _appkey) public onlyApp(_appkey) {
        require(keccak256(abi.encodePacked(wordOfTheDayWinners[msg.sender])) != keccak256(abi.encodePacked(wordOfTheDay)), "You have already collected a reward for guessing the word of the day");
        uint256 tokensEarned = 1000 * 1000000000000000000;
        wordanaToken.transfer(msg.sender, tokensEarned);
        // add XP
        uint256 currentXP =  XP[msg.sender];
        XP[msg.sender] = currentXP + 5;
        emit wordOfTheDayRewardCollected(msg.sender);
    }

    function getWordOfTheDay(string memory _appkey) public onlyApp(_appkey) returns (string memory){
        emit wordOfTheDayReturned(wordOfTheDay);
        return wordOfTheDay;
    }

    function setTokensToBeEarned(uint256 newEarning) public onlyOwner {
        tokensToEarn = newEarning * 1000000000000000000;
    }
}
