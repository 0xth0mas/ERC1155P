// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC1155P.sol";

/**
 * @dev Extension of ERC1155 that adds tracking of total supply per id.
 *
 * Useful for scenarios where Fungible and Non-fungible tokens have to be
 * clearly identified. Note: While a totalSupply of 1 might mean the
 * corresponding is an NFT, there is no guarantees that no other token with the
 * same id are not going to be minted.
 */
abstract contract ERC1155PSupply is ERC1155P {
    /**
     * @dev Custom storage pointer for total token supply. Total supply is 
     *      split into buckets of 8 tokens per bucket allowing for 32 bits 
     *      per token for a max value of 0xFFFFFFFF (~4.3B) of a single token. 
     *      The standard ERC1155P implementation allows a maximum token id
     *      of 0xFFFFFFFFFFFFFFFFFFFFFFFFF which requires a max bucket count of
     *      1FFFFFFFFFFFFFFFFFFFFFFFF. Storage slots for buckets start at
     *      0xF000000000000000000000000000000000000000000000000000000000000000
     *      and continue through
     *      0xF000000000000000000000000000000000000001FFFFFFFFFFFFFFFFFFFFFFFF
     *      There are two addresses 0xF00...000 and 0xF00...001 that could create
     *      storage collisions with wallet balance data however the probability of
     *      that collision is extremely small ~1/2^159.
     */
    uint256 private constant TOTAL_SUPPLY_STORAGE_OFFSET = 0xF000000000000000000000000000000000000000000000000000000000000000;
    uint256 private constant MAX_TOTAL_SUPPLY = 0xFFFFFFFF;

    /**
     * Total supply exceeds maximum.
     */
    error ExceedsMaximumTotalSupply();

    /**
     * @dev Total amount of tokens in with a given id.
     */
    function totalSupply(uint256 id) public view returns (uint256 _totalSupply) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, or(TOTAL_SUPPLY_STORAGE_OFFSET, shr(3, id)))
            _totalSupply := shr(shl(5, and(id, 0x07)), and(sload(mload(ptr)), shl(shl(5, and(id, 0x07)), 0xFFFFFFFF)))
        }
        return _totalSupply;
    }

    /**
     * @dev Sets total supply in custom storage slot location
     */
    function setTotalSupply(uint256 id, uint256 amount) private {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, or(TOTAL_SUPPLY_STORAGE_OFFSET, shr(3, id)))
            mstore(add(ptr, 0x20), sload(mload(ptr)))
            mstore(add(ptr, 0x20), or(and(not(shl(shl(5, and(id, 0x07)), 0xFFFFFFFF)), mload(add(ptr, 0x20))), shl(shl(5, and(id, 0x07)), amount)))
            sstore(mload(ptr), mload(add(ptr, 0x20)))
        }
    }

    /**
     * @dev Indicates whether any token exist with a given id, or not.
     */
    function exists(uint256 id) public view virtual returns (bool) {
        return this.totalSupply(id) > 0;
    }

    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory
    ) internal virtual override {
        if (from == address(0)) {
            uint256 supply = this.totalSupply(id);
            unchecked {
                supply += amount;
            }
            if(supply > MAX_TOTAL_SUPPLY) { ERC1155P._revert(ExceedsMaximumTotalSupply.selector); }
            setTotalSupply(id, supply);
        }

        if (to == address(0)) {
            uint256 supply = this.totalSupply(id);
            unchecked {
                supply -= amount;
            }
            setTotalSupply(id, supply);
        }
    }

    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
     */
    function _beforeBatchTokenTransfer(
        address,
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes memory
    ) internal virtual override {
        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length;) {
                uint256 id = ids[i];
                uint256 supply = this.totalSupply(id);
                unchecked {
                    supply += amounts[i];
                    ++i;
                }
                if(supply > MAX_TOTAL_SUPPLY) { ERC1155P._revert(ExceedsMaximumTotalSupply.selector); }
                setTotalSupply(id, supply);
            }
        }

        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length;) {
                uint256 id = ids[i];
                uint256 supply = this.totalSupply(id);
                unchecked {
                    supply -= amounts[i];
                    ++i;
                }
                setTotalSupply(id, supply);
            }
        }
    }
}