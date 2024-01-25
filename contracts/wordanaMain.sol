// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import "./WordSelector.sol";

contract wordanaMain is RrpRequesterV0, wordSelector {
    enum GameStatus {
        InProgress,
        Canceled,
        Concluded,
        Pending
    }

    enum gamePrizeStatus {
        notAvailable,
        withdrawnByWinner,
        withdrawnByOwner
    }

    struct GameInstance {
        address player1; // player1 address is the unique identifier for each game instance
        address player2;
        uint256 entryPrice; // the amount of wordana tokens each player has to stake to enter the game
        address winner;
        uint256 totalDeposit;
        GameStatus status;
        string wordToGuess;
        uint256 player1Score;
        uint256 player2Score;
        bool player1done;
        bool player2done;
    }

    address public owner;
    address wordanaTokenAddress;
    IERC20 _wordanaToken;

    string private appKey; // the key used by the frontend app to access specific functions

    uint256 public allowedNumberOfGuesses = 6;

    // params for random number generator (API3 QRNG)
    address public airnode;
    bytes32 public endpointIdUint256;
    address public sponsorWallet;
    mapping(bytes32 => bool) public expectingRequestWithIdToBeFulfilled;
    mapping(bytes32 => address) public RequestIdsForGameInstance;

    event wordSelected(bytes32 indexed requestId, address player1Address);
    event player2HasEntered(
        address indexed player1Address,
        address indexed player2Address
    );
    event gameWon(
        address indexed winnerAddress,
        address indexed player1Address
    );
    event playerScoreChanged(address indexed player1Address);
    event gameConcluded(address indexed player1Address);

    mapping(address => GameInstance) private games; // a player can create only one game instance at a time
    GameInstance newGame;
    GameInstance gameToEnter;

    constructor(
        address _tokenAddress,
        address _airnodeRrp,
        string memory _appkey
    ) RrpRequesterV0(_airnodeRrp) {
        owner = msg.sender;
        _wordanaToken = IERC20(_tokenAddress);
        appKey = _appkey;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "you are not the owner of this contract");
        _;
    }

    modifier onlyApp(string memory _appkey) {
        require(
            keccak256(abi.encodePacked(_appkey)) ==
                keccak256(abi.encodePacked(appKey)),
            "App key is invalid"
        );
        _;
    }

    function setRandomNumberRequestParameters(
        address _airnode,
        bytes32 _endpointIdUint256,
        address _sponsorWallet
    ) external onlyOwner {
        airnode = _airnode;
        endpointIdUint256 = _endpointIdUint256;
        sponsorWallet = _sponsorWallet;
    }

    function createGameInstance(address _player2, uint256 _entryPrice) public {
        require(_player2 != msg.sender, "You cannot invite yourself to a game");
        // player1 transfers the entry price in wordana tokens to contract address then
        // setup new game instance
        newGame.player1 = msg.sender;
        newGame.player2 = _player2;
        newGame.entryPrice = _entryPrice;
        newGame.totalDeposit = _entryPrice;
        newGame.status = GameStatus.Pending;
        newGame.player1done = false;
        newGame.player2done = false;

        games[msg.sender] = newGame;

        // deposit entry price
        stakeCoins(msg.sender, wordanaTokenAddress, _entryPrice);

        // make request to api3 qrng to generate random number for picking word to guessWord
        makeRequestUint256(msg.sender);
        return;
    }

    // this function helps player2 enter the game he/she has been invited to
    function enterGame(address _player1) public {
        require(
            games[_player1].status != GameStatus.Concluded,
            "this game has been concluded"
        );
        gameToEnter = games[_player1];
        require(
            gameToEnter.player2 == msg.sender,
            "You were not invited to this game"
        );

        // deposit your own price.
        stakeCoins(msg.sender, wordanaTokenAddress, gameToEnter.entryPrice);
        // update the game to be in progress
        gameToEnter.status = GameStatus.InProgress;
        emit player2HasEntered(_player1, msg.sender);
    }

    function getGameInstance() public view returns (string memory) {
        return games[msg.sender].wordToGuess;
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

        //  Transfer tokens from player to contract:
        token.transferFrom(playerAddress, address(this), requiredAmount);

        return true;
    }

    function updateTokenAddres(
        address _newTokenAddress
    ) public onlyOwner returns (bool) {
        wordanaTokenAddress = _newTokenAddress;
        return true;
    }

    function changeOwner(address _newOwner) public onlyOwner {
        require(
            _newOwner != owner,
            "this new owner is the same as the old one"
        );
        owner = _newOwner;
    }

    function makeRequestUint256(address player1Address) private {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256,
            address(this),
            sponsorWallet,
            address(this),
            this.selectWord.selector,
            ""
        );

        expectingRequestWithIdToBeFulfilled[requestId] = true;
        RequestIdsForGameInstance[requestId] = player1Address;
    }

    function selectWord(
        bytes32 requestId,
        bytes calldata data
    ) external onlyAirnodeRrp {
        require(
            expectingRequestWithIdToBeFulfilled[requestId],
            "Request id unknown"
        );
        expectingRequestWithIdToBeFulfilled[requestId] = false;
        uint256 randomNumber = abi.decode(data, (uint256));

        // the index should be in the range of 0 - 260
        uint256 wordIndex = (randomNumber % (260 - 0 + 1)) + 0;

        address currentPlayer1 = RequestIdsForGameInstance[requestId];
        games[currentPlayer1].wordToGuess = getWord(wordIndex);

        // emit an event here
        emit wordSelected(requestId, currentPlayer1);
    }

    // checkword
    function getGameWord(
        address player1Address,
        string memory _appkey
    ) public view onlyApp(_appkey) returns (string memory) {
        if (msg.sender != player1Address) {
            require(
                msg.sender == games[player1Address].player2,
                "you are not a participant in the game"
            );
        }
        return games[player1Address].wordToGuess;
    }

    // record score
    function recordGameScore(
        address player1Address,
        uint256 _newScore,
        string memory _appkey,
        bool currentPlayerIsdone
    ) public onlyApp(_appkey) {
        require(
            games[player1Address].status == GameStatus.InProgress,
            "this game is no longer in progress"
        );
        if (msg.sender != player1Address) {
            require(
                msg.sender == games[player1Address].player2,
                "you are not a participant in the game"
            );
            games[player1Address].player2Score = _newScore;
            games[player1Address].player2done = currentPlayerIsdone;
            if (currentPlayerIsdone && games[player1Address].player1done) {
                concludeGame(player1Address);
            }
        } else {
            games[player1Address].player1Score = _newScore;
            games[player1Address].player1done = currentPlayerIsdone;
            if (currentPlayerIsdone && games[player1Address].player2done) {
                concludeGame(player1Address);
            }
        }
        emit playerScoreChanged(player1Address);
    }

    function concludeGame(address player1Address) private {
        games[player1Address].status = GameStatus.Concluded;
        // calculate winner
        if (
            games[player1Address].player1Score >
            games[player1Address].player2Score
        ) {
            games[player1Address].winner = games[player1Address].player1;
        } else if (
            games[player1Address].player1Score <
            games[player1Address].player2Score
        ) {
            games[player1Address].winner = games[player1Address].player2;
        }
        emit gameConcluded(player1Address);
    }

    function getWinner(address player1Address) public view returns (address) {
        return games[player1Address].winner;
    }
}
