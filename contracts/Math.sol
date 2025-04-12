// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Math {
    /// @notice 计算 `x^(1/n)`，使用二分法逼近
    function nthRoot(uint256 x, uint256 n, uint256 precision) internal pure returns (uint256) {
        uint256 low = 1;
        uint256 high = x;
        uint256 mid;

        while (high - low > precision) {
            mid = (low + high) / 2;
            uint256 midPow = power(mid, n);

            if (midPow == x) {
                return mid;
            } else if (midPow < x) {
                low = mid;
            } else {
                high = mid;
            }
        }
        return (low + high) / 2;
    }

    /// @notice 计算 `base^exp`，防止溢出
    function power(uint256 base, uint256 exp) internal pure returns (uint256) {
        uint256 result = 1e18;
        uint256 x = base;
        while (exp > 0) {
            if (exp % 2 == 1) {
                result = (result * x) / 1e18;
            }
            x = (x * x) / 1e18;
            exp /= 2;
        }
        return result;
    }
} 


contract RandomWalk {
    mapping(address => uint256[]) internal tokenPriceWindow;
    uint256 internal windowLength = 10;

    function getRandomNumber(uint256 seed) internal view returns (uint) {
        uint256 random = uint256(
            keccak256(
                abi.encodePacked(
                    seed,              // 输入的随机数种子
                    block.timestamp,   // 当前区块时间戳
                    block.prevrandao,  // 过去区块的随机数
                    msg.sender         // 调用者地址
                )
            )
        );
        return random % 5;
    }

    function walk(address token, uint256 initAmount, uint256 initTime, uint256 times, uint256 std) internal returns (uint256) {
        for (uint i = 0; i < times; i++) {
            uint256 tempStd = std; // 避免 std 被修改
            while (tempStd > 0) {
                uint randomStep = getRandomNumber(initAmount); // 可能为负数
                if (initAmount + uint256(randomStep) * tempStd > 2 * tempStd) {
                    initAmount += uint256(randomStep) * tempStd - 2 * tempStd; 
                } else {
                    initAmount = 0;
                }
                tempStd /= 10;
                tokenPriceWindow[token][(initTime + i) % windowLength] = initAmount;
            }
        }
        return initAmount;
    }
}