// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./interfaces/IReputationManager.sol";

contract ReputationManager is IReputationManager {

    struct Rating {
        uint256 totalScore;
        uint256 count;
        uint256 lastUpdateTimestamp;
    }

    struct UserRating {
        uint256 rating;
        uint256 lastUpdateTimestamp;
    }

    mapping(address => mapping(address => UserRating)) private userRatings;
    mapping(address => Rating) private userAverages;
    mapping(address => bool) private registeredRatingTypes;

    event RatingTypeRegistered(address ratingType);
    event RatingUpdated(address user, address ratingType, uint256 rating);

    modifier onlyRegisteredRatingType(address ratingType) {
        require(registeredRatingTypes[ratingType], "Rating type not registered");
        _;
    }

    function register(address ratingType) external override {
        require(!registeredRatingTypes[ratingType], "Rating type already registered");
        registeredRatingTypes[ratingType] = true;
        emit RatingTypeRegistered(ratingType);
    }

    function update(address user, uint256 rating, address ratingType) external override onlyRegisteredRatingType(ratingType) {
        UserRating storage userRating = userRatings[user][ratingType];
        Rating storage average = userAverages[user];

        userRating.rating = rating;
        userRating.lastUpdateTimestamp = block.timestamp;

        if (average.count == 0) {
            average.totalScore = rating;
            average.count = 1;
        } else {
            average.totalScore += rating;
            average.count += 1;
        }
        average.lastUpdateTimestamp = block.timestamp;

        emit RatingUpdated(user, ratingType, rating);
    }

    function getAverage(address user) external view override returns (uint256 averageRating, uint256 ratingCount, uint256 lastUpdateTimestamp) {
        Rating storage average = userAverages[user];
        if (average.count == 0) {
            return (0, 0, 0);
        }
        return (average.totalScore / average.count, average.count, average.lastUpdateTimestamp);
    }

    function getRating(address user, address ratingType) external view override onlyRegisteredRatingType(ratingType) returns (uint256 rating, uint256 lastUpdateTimestamp) {
        UserRating storage userRating = userRatings[user][ratingType];
        return (userRating.rating, userRating.lastUpdateTimestamp);
    }
}