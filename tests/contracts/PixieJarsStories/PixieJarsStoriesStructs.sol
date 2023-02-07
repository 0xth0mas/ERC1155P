// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

struct MintRecipe {
    uint32 cost; //in GWEI
    uint32 startTime;
    uint32 endTime;
    uint32 pixieDustCost;
    uint256[] mintTokenIds;
    uint256[] mintTokenQuantities;
    uint256[] burnTokenIds;
    uint256[] burnTokenQuantities;
}