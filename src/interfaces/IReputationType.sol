// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IReputationType {
    struct UserState {
        uint256 totalScore;
        uint256 ratingCount;
    }

    function update(address user, uint256 rating) external;

    function getReputation(address user) external view returns (uint256 averageRating, uint256 ratingCount);
}