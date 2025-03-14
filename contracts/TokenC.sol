// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyToken.sol";

contract TokenC is MyToken {
    constructor(uint _initialSupply) MyToken(_initialSupply) {}
    function name() public view virtual override returns (string memory) {
        return "TokenC";
    }
}