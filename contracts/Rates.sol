// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RateCaculator {

    function getCurrentTimeView() internal view returns (uint256) {
        return block.timestamp;
    }


}