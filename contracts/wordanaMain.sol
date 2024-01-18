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
        address player1;
        address player2;
        uint256 entryPrice; // the amount of wordana tokens each player has to stake to enter the game
        address winner;
        uint256 totalDeposit;
        GameStatus status;
        string wordToGuess;
    }

    address public owner;
    address wordanaTokenAddress;
    IERC20 _wordanaToken;

    address public airnode;
    bytes32 public endpointIdUint256;
    bytes32 public endpointIdUint256Array;
    address public sponsorWallet;

    mapping (bytes32 => bool) public  expectingRequestWithIdToBeFulfilled;
    mapping (bytes32 => address) public  RequestIdsForGameInstance;

    uint256 public num;

    event RequestUint256(bytes32 indexed requestId, address indexed );

    mapping(address=>GameInstance) private  games;  // a player can create only one game instance at a time
    GameInstance newGame;
    GameInstance gameToEnter;

    constructor(address _tokenAddress, address _airnodeRrp) RrpRequesterV0(_airnodeRrp){
        owner = msg.sender;
        _wordanaToken = IERC20(_tokenAddress);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'you are not the owner of this contract');
        _;
    }

    modifier checkAllowance(uint amount) {
        require(_wordanaToken.allowance(msg.sender, address(this)) >= amount, "Error: not approved");
        _;
    }

    function setRandomNumberRequestParameters(address _airnode,
     bytes32 _endpointIdUint256, 
     bytes32 _endpointIdUint256Array,
     address _sponsorWallet) external onlyOwner {
        airnode = _airnode;
        endpointIdUint256 = _endpointIdUint256;
        endpointIdUint256Array = _endpointIdUint256Array;
        sponsorWallet = _sponsorWallet;
    }

    function createGameInstance (address _player2, uint256 _entryPrice) public {
        require(_player2 != msg.sender, "You cannot invite yourself to a game");
        // player1 transfers the entry price in wordana tokens to contract address then
        // setup new game instance
        newGame.player1 = msg.sender;
        newGame.player2 = _player2;
        newGame.entryPrice = _entryPrice;
        newGame.totalDeposit = _entryPrice;
        newGame.status = GameStatus.Pending;
        games[msg.sender] = newGame;

        // make request to api3 qrng to generate random number for picking word to guess
         makeRequestUint256(msg.sender);
        return ;
    }

    // this function helps player2 enter the game he/she has been invited to
    function enterGame (address _player1) public returns (bool){
        gameToEnter = games[_player1];
        require(gameToEnter.player2 == msg.sender, "You were not invited to this game");

        // deposit your own price.
        // update the game to be in progress
        gameToEnter.status = GameStatus.InProgress;
        return true;
    }

    function getGameInstance () public view returns (string memory){
        return  games[msg.sender].wordToGuess;
    }

    function stakeCoins (uint amount) public returns (bool){
        _wordanaToken.approve(address(this), amount);
        _wordanaToken.transferFrom(msg.sender, address(this), amount);
        return true;
    }

    function updateTokenAddres (address _newTokenAddress) public onlyOwner returns (bool){
        wordanaTokenAddress = _newTokenAddress;
        return true;
    }

    function changeOwner (address _newOwner) public onlyOwner returns (bool){
        require(_newOwner != owner, "this new owner is the same as the old one");
        owner = _newOwner;
        return true;
    }

    function makeRequestUint256(address player1Address) private  {
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

    function selectWord(bytes32 requestId, bytes calldata data) external onlyAirnodeRrp {
        require(expectingRequestWithIdToBeFulfilled[requestId], "Request id unknown");
        expectingRequestWithIdToBeFulfilled[requestId] = false;
        uint256 randomNumber = abi.decode(data, (uint256));

        // the index should be in the range of 0 - 260
        uint256 wordIndex = (randomNumber % (260 - 0 + 1)) + 0;

        num = wordIndex;

        address currentGame = RequestIdsForGameInstance[requestId];
        games[currentGame].wordToGuess = getWord(wordIndex);

        // emit an event here
    }

}