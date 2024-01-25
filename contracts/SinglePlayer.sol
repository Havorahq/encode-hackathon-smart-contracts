// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./WordSelector.sol";
import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";

contract WordanaGame is RrpRequesterV0, wordSelector  {
    // Wordana token contract
    IERC20 public wordanaToken;
    address public owner;
    string public wordOfTheDay;
    uint256 public tokensToEarn;

    // params for random number generator (API3 QRNG)
    address public airnode;
    bytes32 public endpointIdUint256;
    address public sponsorWallet;
    mapping (bytes32 => bool) public  expectingRequestWithIdToBeFulfilled;
    uint256 public sindex;


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

    // Start the game and set the Wordana token contract
    constructor(address _wordanaToken, uint256 _tokensToEarn, address _airnodeRrp) RrpRequesterV0(_airnodeRrp) {
        require(_wordanaToken != address(0), "Invalid Wordana token address");
        owner = msg.sender;
        wordanaToken = IERC20(_wordanaToken);
        tokensToEarn = _tokensToEarn * 1000000000000000000 ;
        emit GameStarted(msg.sender);
    }

    function setReward(uint256 _tokensToEarn) public onlyOwner {
        tokensToEarn = _tokensToEarn*1000000000000000000;
    }

    function setRandomNumberRequestParameters(address _airnode,
     bytes32 _endpointIdUint256, 
     address _sponsorWallet) external onlyOwner {
        airnode = _airnode;
        endpointIdUint256 = _endpointIdUint256;
        sponsorWallet = _sponsorWallet;
    }

    function makeRequestUint256() public onlyOwner  {
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
        emit RequestUint256(requestId);
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

    function selectWord(bytes32 requestId, bytes calldata data) external onlyAirnodeRrp {
        require(expectingRequestWithIdToBeFulfilled[requestId], "Request id unknown");
        expectingRequestWithIdToBeFulfilled[requestId] = false;
        uint256 randomNumber = abi.decode(data, (uint256));
        // the index should be in the range of 0 - 260
        uint256 wordIndex = (randomNumber % (260 - 0 + 1)) + 0;
        sindex = wordIndex;
        setWordOfTheDay(wordIndex);
        emit wordOfTheDaySet();
    }
}