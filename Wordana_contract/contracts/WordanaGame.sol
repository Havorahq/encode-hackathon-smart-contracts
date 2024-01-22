// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./WordSelector.sol";

contract WordanaGame is Ownable {
    // Wordana token contract
    IERC20 public wordanaToken;

    // WordSelector contract
    WordSelector public wordSelector;

    // Events
    event GameStarted(address indexed player);
    event WordGuessed(address indexed player, string guessedWord, bool isCorrect);
    event TokensRewarded(address indexed player, uint256 tokensEarned);

    // Modifiers
    modifier onlyIfGameStarted() {
        require(wordanaToken != IERC20(address(0)), "Game has not started yet");
        _;
    }

    // Start the game and set the Wordana token contract
    constructor(address _wordanaToken, address _wordSelectorAddress) {
        require(_wordanaToken != address(0), "Invalid Wordana token address");
        wordanaToken = IERC20(_wordanaToken);
        wordSelector = WordSelector(_wordSelectorAddress);
        emit GameStarted(msg.sender);
    }

    // Player guesses the word
    function guessWord(uint256 _index) external onlyIfGameStarted {
        require(_index >= 0 && _index < 261, "Index out of range");

        string memory guessedWord = wordSelector.getWord(_index);
        bool isCorrect = checkWord(guessedWord);
        emit WordGuessed(msg.sender, guessedWord, isCorrect);

        if (isCorrect) {
            // Reward the player with Wordana tokens
            uint256 tokensEarned = 100; // Adjust the number of tokens as needed
            wordanaToken.transfer(msg.sender, tokensEarned);
            emit TokensRewarded(msg.sender, tokensEarned);
        }
    }

    // Check if the guessed word is correct
    function checkWord(string memory _guessedWord) internal view returns (bool) {
        for (uint256 i = 0; i < 261; i++) {
            string memory word = wordSelector.getWord(i);
            if (keccak256(abi.encodePacked(_guessedWord)) == keccak256(abi.encodePacked(word))) {
                return true;
            }
        }
        return false;
    }

    // Owner function to withdraw any accidentally sent ERC20 tokens
    function withdrawTokens(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(owner(), _amount);
    }
}