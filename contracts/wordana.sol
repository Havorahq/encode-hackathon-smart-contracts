// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract wordana {

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
    mapping(address=>GameInstance) private  games;  // a player can create only one game instance at a time
    GameInstance newGame;
    GameInstance gameToEnter;

    constructor() {
        owner = msg.sender;
    }

    function createGameInstance (address _player2, uint256 _entryPrice) public returns(bool){
        require(_player2 != msg.sender, "You cannot invite yourself to a game");
        // player1 transfers the entry price in wordana tokens to contract address then
        // setup new game instance
        newGame.player1 = msg.sender;
        newGame.player2 = _player2;
        newGame.entryPrice = _entryPrice;
        newGame.totalDeposit = _entryPrice;
        newGame.status = GameStatus.Pending;

        // pick word to guess
        newGame.wordToGuess = "pickle";

        games[msg.sender] = newGame;

        return  true;
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

    function getGameInstance () public view returns (address){
        return  games[msg.sender].player2;
    }

}