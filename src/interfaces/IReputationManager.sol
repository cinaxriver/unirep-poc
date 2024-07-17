// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IReputationManager {
    function register(address ratingType) external;
    function update(address user, uint256 rating, address ratingType) external;
    function getAverage(address user) external view returns (uint256 averageRating, uint256 ratingCount, uint256 lastUpdateTimestamp);
    function getRating(address user, address ratingType) external view returns (uint256 rating, uint256 lastUpdateTimestamp);
}