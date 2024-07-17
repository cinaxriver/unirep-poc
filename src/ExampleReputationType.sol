// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/IReputationType.sol";

contract ExampleReputationType is IReputationType {
    mapping(address => UserState) private userStates;

    event ReputationUpdated(address indexed user, uint256 newRating, uint256 newAverage);

    function update(address user, uint256 rating) external override {
        UserState storage state = userStates[user];

        state.totalScore += rating;
        state.ratingCount += 1;

        uint256 newAverage = calculateAverage(state);

        emit ReputationUpdated(user, rating, newAverage);
    }

    function getReputation(address user) external view override returns (uint256 averageRating, uint256 ratingCount) {
        UserState memory state = userStates[user];

        if (state.ratingCount == 0) {
            return (0, 0);
        }

        averageRating = calculateAverage(state);
        ratingCount = state.ratingCount;
    }

    function calculateAverage(UserState memory state) internal pure returns (uint256) {
        if (state.ratingCount == 0) {
            return 0;
        }
        return state.totalScore / state.ratingCount;
    }

    function resetUserState(address user) external {
        delete userStates[user];
    }

    function getUserState(address user) external view returns (UserState memory) {
        return userStates[user];
    }
}