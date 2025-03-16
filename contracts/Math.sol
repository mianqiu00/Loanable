// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract FixedPointMath {
    uint256 constant SCALING_FACTOR = 1e10; // 10^5，表示5位小数

    // uint256 转换为放大 10^5 倍的数（相当于小数转换）
    function toFixed(uint256 value) public pure returns (uint256) {
        return value * SCALING_FACTOR;
    }

    // 还原回 uint256（除以 10^5）
    function fromFixed(uint256 scaledValue) public pure returns (uint256) {
        return scaledValue / SCALING_FACTOR;
    }

    function addFixed(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }

    function mulFixed(uint256 a, uint256 b) public pure returns (uint256) {
        return (a * b) / SCALING_FACTOR;
    }
}
