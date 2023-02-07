// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPixieDust {
    function burnDust(address from, uint256 amount) external;
    function mintDust(address to, uint256 amount) external;
}