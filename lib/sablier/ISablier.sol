// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISablier {
    struct CreateWithDurations {
        address sender;
        bool cancelable;
        bool transferable;
        address recipient;
        uint128 totalAmount;
        IERC20 asset;
        uint40 cliffDuration;
        uint40 totalDuration;
    }

    function createWithDurations(CreateWithDurations calldata params) external returns (uint256 streamId);
}
