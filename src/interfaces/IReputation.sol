// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IReputation {
    function calculate(uint256[] memory data) external pure returns (uint256);
}