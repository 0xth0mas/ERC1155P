// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/IPixieJarsStories.sol";
import "../ERC1155P/extensions/ERC1155PSupply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PixieJarsStories is IPixieJarsStories, ERC1155PSupply, Ownable {
    /**
     * @dev Mapping of allowed minter addresses to access burn/mint functions
     */
    mapping(address => bool) private allowedMinter;

    modifier onlyAllowedMinter() {
        if (!allowedMinter[msg.sender]) {
            revert UnauthorizedMinter();
        }
        _;
    }

    constructor() ERC1155P("Pixie Jars Stories", "PJS") {}

    /**
     * @dev Mints single token for given address, can only be called by authorized minting contracts.
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) external onlyAllowedMinter {
        _mint(to, id, amount, "");
    }

    /**
     * @dev Mints batch of tokens for given address, can only be called by authorized minting contracts.
     */
    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyAllowedMinter {
        _mintBatch(to, ids, amounts, "");
    }

    /**
     * @dev Burns single token for given address, can only be called by authorized minting contracts.
     */
    function burn(
        address from,
        uint256 burnId,
        uint256 burnAmount
    ) external onlyAllowedMinter {
        _burn(from, burnId, burnAmount);
    }

    /**
     * @dev Burns batch of tokens for given address, can only be called by authorized minting contracts.
     */
    function burnBatch(
        address from,
        uint256[] calldata burnIds,
        uint256[] calldata burnAmounts
    ) external onlyAllowedMinter {
        _burnBatch(from, burnIds, burnAmounts);
    }

    /**
     * @dev Sets allowed for given minter. Allows address to call the mint and burn functions.
     */

    function setAllowedMinter(address minter, bool allowed) external onlyOwner {
        allowedMinter[minter] = allowed;
    }

    /**
     * @dev Sets `tokenURI` as the tokenURI of `tokenId`.
     */
    function setTokenURI(
        uint256 tokenId,
        string calldata tokenURI
    ) external onlyOwner {
        //_setURI(tokenId, tokenURI);
    }

    function tmpSeaportMock(
        address[] calldata from,
        address[] calldata to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external {
        for (uint256 i = 0; i < from.length; i++) {
            safeTransferFrom(from[i], to[i], ids[i], amounts[i], "");
        }
    }
}
