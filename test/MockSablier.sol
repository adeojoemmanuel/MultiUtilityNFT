// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../lib/sablier/ISablier.sol";

contract MockSablier is ISablier {
    struct Stream {
        address sender;
        address recipient;
        IERC20 asset;
        uint128 amount;
        uint40 startTime;
        uint40 duration;
    }

    uint256 public nextStreamId;
    mapping(uint256 => Stream) public streams;

    function createWithDurations(CreateWithDurations calldata params) external returns (uint256 streamId) {
        streamId = nextStreamId++;
        streams[streamId] = Stream({
            sender: params.sender,
            recipient: params.recipient,
            asset: params.asset,
            amount: params.totalAmount,
            startTime: uint40(block.timestamp),
            duration: params.totalDuration
        });
        return streamId;
    }
}