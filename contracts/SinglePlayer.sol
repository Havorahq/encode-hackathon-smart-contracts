// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./WordSelector.sol";

contract WordanaGame is  wordSelector  {
    // Wordana token contract
    IERC20 public wordanaToken;
    address public owner;
    string private wordOfTheDay;
    uint256 public tokensToEarn;
    string private appkey;


    // Events
    event GameStarted(address indexed player);
    event WordGuessed(address indexed player, string guessedWord, bool isCorrect);
    event TokensRewarded(address indexed player, uint256 tokensEarned);
    event wordOfTheDaySet();
    event RequestUint256(bytes32 indexed requestId);

    modifier onlyOwner() {
        require(msg.sender == owner, "you are not the owner of this contract");
        _;
    }

    // Modifiers
    modifier onlyIfGameStarted() {
        require(wordanaToken != IERC20(address(0)), "Game has not started yet");
        _;
    }

    modifier onlyApp(string memory _appkey) {
        require(keccak256(abi.encodePacked(_appkey)) == keccak256(abi.encodePacked(appkey)), "App key is invalid");
        _;
    }

    // Start the game and set the Wordana token contract
    constructor(address _wordanaToken, uint256 _tokensToEarn, string memory _appkey) {
        require(_wordanaToken != address(0), "Invalid Wordana token address");
        owner = msg.sender;
        wordanaToken = IERC20(_wordanaToken);
        tokensToEarn = _tokensToEarn * 1000000000000000000 ;
        appkey = _appkey;
        emit GameStarted(msg.sender);
    }

    function setReward(uint256 _tokensToEarn) public onlyOwner {
        tokensToEarn = _tokensToEarn*1000000000000000000;
    }

    // Player guesses the word
    function guessWord(string memory guessedWord) external onlyIfGameStarted returns(bool) {
        bool isCorrect = checkWord(guessedWord);
        emit WordGuessed(msg.sender, guessedWord, isCorrect);

        if (isCorrect) {
            // Reward the player with Wordana tokens
            uint256 tokensEarned = tokensToEarn;
            wordanaToken.transfer(msg.sender, tokensEarned);
            emit TokensRewarded(msg.sender, tokensEarned);
        }

        return isCorrect;
    }

    // Check if the guessed word is correct
    function checkWord(string memory _guessedWord) internal view returns (bool) {
        if (keccak256(abi.encodePacked(_guessedWord)) == keccak256(abi.encodePacked(wordOfTheDay))) {
            return true;
        }
        return false;
    }

    // Owner function to withdraw any accidentally sent ERC20 tokens
    function withdrawTokens(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(owner, _amount);
    }

    function setWordOfTheDay(uint256 index) public onlyOwner {
        // will use api3qrng
        wordOfTheDay = getWord(index);
        emit wordOfTheDaySet();
    }

    function getWordOfTheDay(string memory _appkey) public onlyApp(_appkey) view returns (string memory){
        return wordOfTheDay;
    }
}