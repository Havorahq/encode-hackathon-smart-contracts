// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";


contract testApproval {

    IERC20 public wordanaToken;
    
    constructor (address _tokenAddress){
        wordanaToken = IERC20(_tokenAddress);
    }

    function approveContract (uint256 amount) public returns (bool){
        wordanaToken.approve(address(this), amount);
        return true;
    } 

    function transfertTokens (uint256 amount) public {
        wordanaToken.transferFrom(msg.sender, address(this), amount);
    }

}