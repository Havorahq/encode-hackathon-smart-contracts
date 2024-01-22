// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";

contract randomNumberGenerator is RrpRequesterV0{

    address public airnode;
    bytes32 public endpointIdUint256;
    bytes32 public endpointIdUint256Array;
    address public sponsorWallet;

    uint256 public qrngUint256;

    mapping (bytes32 => bool) public  expectingRequestWithIdToBeFulfilled;

    event RequestUint256(bytes32 indexed requestId);
    event ReceivedUint256(bytes32 indexed requestId, uint256 response);

    constructor(address _airnodeRrp) RrpRequesterV0(_airnodeRrp){

    }

    function setRequestParameters(address _airnode,
     bytes32 _endpointIdUint256, 
     bytes32 _endpointIdUint256Array,
     address _sponsorWallet) external {
        airnode = _airnode;
        endpointIdUint256 = _endpointIdUint256;
        endpointIdUint256Array = _endpointIdUint256Array;
        sponsorWallet = _sponsorWallet;
    }

    function makeRequestUint256() external {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256.selector,
            ""
        );

        expectingRequestWithIdToBeFulfilled[requestId] = true;
        emit RequestUint256(requestId);
    }


    function fulfillUint256(bytes32 requestId, bytes calldata data) external onlyAirnodeRrp {
        require(expectingRequestWithIdToBeFulfilled[requestId], "Request id unknown");
        expectingRequestWithIdToBeFulfilled[requestId] = false;
        qrngUint256 = abi.decode(data, (uint256));

        emit ReceivedUint256(requestId, qrngUint256);
    }

}