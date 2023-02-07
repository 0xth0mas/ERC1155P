// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPixieJarsStories {

    error UnauthorizedMinter();

    function mint(address to, uint256 id, uint256 amount) external;
    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts) external;
    function burn(address from, uint256 burnId, uint256 burnAmount) external;
    function burnBatch(address from, uint256[] calldata burnIds, uint256[] calldata burnAmounts) external;
    function setAllowedMinter(address minter, bool allowed) external;
}