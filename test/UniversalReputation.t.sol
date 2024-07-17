// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UniversalReputation.sol";
import "../src/interfaces/IReputationManager.sol";
import "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";
import "../src/ExampleReputationType.sol";
import "../src/ReputationManager.sol";

contract UniversalReputationTest is WormholeRelayerBasicTest {
    event ReputationUpdated(address user, address ratingType, uint256 rating);
    event CrossChainReputationReceived(uint16 sourceChain, bytes32 sourceAddress, address user, uint256 rating, address ratingType);

    UniversalReputation reputationSource;
    UniversalReputation reputationTarget;
    ReputationManager managerSource;
    ReputationManager managerTarget;
    ExampleReputationType reputationTypeSource;
    ExampleReputationType reputationTypeTarget;

    uint16 constant SOURCE_CHAIN_ID = 1;
    uint16 constant TARGET_CHAIN_ID = 2;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public ratingType1 = address(0x4);
    address public ratingType2 = address(0x5);

    function setUpSource() public override {
        reputationTypeSource = new ExampleReputationType();
        managerSource = new ReputationManager();
        reputationSource = new UniversalReputation(
            owner,
            address(managerSource),
            address(wormholeSource),
            address(relayerSource),
            sourceChain
        );
    }

    function setUpTarget() public override {
        reputationTypeTarget = new ExampleReputationType();
        managerTarget = new ReputationManager();
        reputationTarget = new UniversalReputation(
            owner,
            address(managerTarget),
            address(wormholeTarget),
            address(relayerTarget),
            targetChain
        );
    }



    function testSetReputationManager() public {
        address newManager = address(0x6);
        vm.prank(owner);
        reputationSource.setReputationManager(newManager);
        assertEq(address(reputationSource.reputationManager()), newManager);
    }

    function testRegisterRatingType() public {
        address newRatingType = address(0x7);
        vm.prank(owner);
        reputationSource.registerRatingType(newRatingType);
    }

    function testExecuteReputation() public {
        vm.prank(owner);
        reputationSource.executeReputation(user1, 5, ratingType1);

        (uint256 averageRating, uint256 ratingCount, ) = reputationSource.getUserReputation(user1);
        assertEq(averageRating, 5);
        assertEq(ratingCount, 1);
    }

    function testGetUserReputation() public {
        vm.startPrank(owner);
        reputationSource.executeReputation(user1, 4, ratingType1);
        reputationSource.executeReputation(user1, 6, ratingType2);
        vm.stopPrank();

        (uint256 averageRating, uint256 ratingCount, ) = reputationSource.getUserReputation(user1);
        assertEq(averageRating, 5);
        assertEq(ratingCount, 2);
    }

    function testSendCrossChainReputation() public {
        uint256 cost = reputationSource.quoteCrossChainPrice(TARGET_CHAIN_ID);

        vm.prank(owner);
        vm.deal(owner, cost);
        reputationSource.sendCrossChainReputation{value: cost}(TARGET_CHAIN_ID, user2, 8, ratingType1);

        vm.recordLogs();
        performDelivery();

        vm.selectFork(targetFork);

        (uint256 rating, ) = reputationTarget.getUserRatingByType(user2, ratingType1);
        assertEq(rating, 8);
    }

    function testReceiveWormholeMessages() public {
        bytes32 sourceAddress = toWormholeFormat(address(reputationSource));
        UniversalReputation.ReputationMessage memory message = UniversalReputation.ReputationMessage(user2, 7, ratingType2);
        bytes memory payload = abi.encode(message);

        vm.prank(address(wormholeTarget));
        reputationTarget.receiveWormholeMessages(
            payload,
            new bytes[](0),
            sourceAddress,
            SOURCE_CHAIN_ID,
            bytes32(0)
        );

        (uint256 rating, ) = reputationTarget.getUserRatingByType(user2, ratingType2);
        assertEq(rating, 7);
    }

    function testUntrustedSource() public {
        bytes32 untrustedSource = toWormholeFormat(address(0x8));
        UniversalReputation.ReputationMessage memory message = UniversalReputation.ReputationMessage(user2, 9, ratingType1);
        bytes memory payload = abi.encode(message);

        vm.prank(address(wormholeTarget));
        vm.expectRevert("Untrusted source");
        reputationTarget.receiveWormholeMessages(
            payload,
            new bytes[](0),
            untrustedSource,
            SOURCE_CHAIN_ID,
            bytes32(0)
        );
    }

    function testExampleReputationTypeDirectly() public {
        reputationTypeSource.update(user1, 5);
        (uint256 averageRating, uint256 ratingCount) = reputationTypeSource.getReputation(user1);
        assertEq(averageRating, 5);
        assertEq(ratingCount, 1);

        reputationTypeSource.update(user1, 7);
        (averageRating, ratingCount) = reputationTypeSource.getReputation(user1);
        assertEq(averageRating, 6);
        assertEq(ratingCount, 2);

        ExampleReputationType.UserState memory state = reputationTypeSource.getUserState(user1);
        assertEq(state.totalScore, 12);
        assertEq(state.ratingCount, 2);

        reputationTypeSource.resetUserState(user1);
        (averageRating, ratingCount) = reputationTypeSource.getReputation(user1);
        assertEq(averageRating, 0);
        assertEq(ratingCount, 0);
    }

}