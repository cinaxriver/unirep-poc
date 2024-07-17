// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

import "wormhole-solidity-sdk/interfaces/IWormhole.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/Base.sol";

import "./interfaces/IReputationManager.sol";

/*
 this is just proof of concept, in real world scenario we would have to implement more complex logic
 not use this in production


 a contract that allows to update reputation of users and get their reputation


*/
contract UniversalReputation is Base, Ownable, IWormholeReceiver {

    struct ReputationMessage {
        address user;
        uint256 rating;
        address ratingType;
    }

    uint256 constant GAS_LIMIT = 50_000;

    IReputationManager public reputationManager;

    uint16 public chainId;
    mapping(address => bool) reputationManagers;

    event ReputationUpdated(address user, address ratingType, uint256 rating);
    event CrossChainReputationReceived(uint16 sourceChain, bytes32 sourceAddress, address user, uint256 rating, address ratingType);

    constructor(address _initialOwner,
        address _reputationManager,
        address _wormhole,
        address _wormholeRelayer,
        uint16 _chainId) Ownable(_initialOwner) Base(_wormholeRelayer, _wormhole) {
        reputationManager = IReputationManager(_reputationManager);
        chainId = _chainId;
    }

    modifier onlyReputationManager() {
        require(reputationManagers[msg.sender], "Not a reputation manager");
        _;
    }

    function addReputationManager(address _reputationManager) external onlyOwner {
        reputationManagers[_reputationManager] = true;
    }

    function removeReputationManager(address _reputationManager) external onlyOwner {
        reputationManagers[_reputationManager] = false;
    }

    function quoteCrossChainPrice(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT
        );
    }

    function setReputationManager(address _newManager) external onlyOwner {
        reputationManager = IReputationManager(_newManager);
    }

    function registerRatingType(address ratingType) external onlyOwner {
        reputationManager.register(ratingType);
    }

    function executeReputation(address user, uint256 rating, address ratingType) external onlyReputationManager {
        reputationManager.update(user, rating, ratingType);
        emit ReputationUpdated(user, ratingType, rating);
    }

    function getUserReputation(address user) external view returns (uint256 averageRating, uint256 ratingCount, uint256 lastUpdateTimestamp) {
        return reputationManager.getAverage(user);
    }

    function getUserRatingByType(address user, address ratingType) external view returns (uint256 rating, uint256 lastUpdateTimestamp) {
        return reputationManager.getRating(user, ratingType);
    }

    function sendCrossChainReputation(uint16 targetChain, address user, uint256 rating, address ratingType) external payable onlyReputationManager {
        ReputationMessage memory message = ReputationMessage(user, rating, ratingType);
        uint256 cost = quoteCrossChainPrice(targetChain);
        require(msg.value == cost, "Incorrect payment amount");

        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            address(this),
            abi.encode(user, rating, ratingType),
            0,
            GAS_LIMIT
        );
    }

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory additionalMessages,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) public payable override onlyWormholeRelayer isRegisteredSender(sourceChain, sourceAddress) {

        (address user, uint256 rating, address ratingType) = abi.decode(
            payload,
            (address, uint256, address)
        );

        reputationManager.update(user, rating, ratingType);

        emit ReputationUpdated(user, ratingType, rating);
        emit CrossChainReputationReceived(sourceChain, sourceAddress, user, rating, ratingType);
    }
}