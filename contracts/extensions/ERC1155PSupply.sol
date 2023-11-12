// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

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
     *      split into buckets of 4 tokens per bucket allowing for 64 bits
     *      per token. 
     *      32 bits are used to store total supply for a max value of 0xFFFFFFFF 
     *      (~4.3B) of a single token. 
     *      32 bits are used to store the mint count for a token
     * 
     *      The standard ERC1155P implementation allows a maximum token id
     *      of 0x07FFFFFFFFFFFFFFFFFFFFFFF which requires a max bucket id of
     *      0x1FFFFFFFFFFFFFFFFFFFFFFF. Storage slots for buckets start at
     *      0xF000000000000000000000000000000000000000000000000000000000000000
     *      and continue through
     *      0xF0000000000000000000000000000000000000001FFFFFFFFFFFFFFFFFFFFFFF
     * 
     *      Storage pointers for ERC1155P account balances start at
     *      0xE000000000000000000000000000000000000000000000000000000000000000
     *      and continue through
     *      0xEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
     * 
     *      All custom pointers get hashed to avoid potential conflicts with
     *      standard mappings or incorrect returns on view functions.
     */
    uint256 private constant TOTAL_SUPPLY_STORAGE_OFFSET =
        0xF000000000000000000000000000000000000000000000000000000000000000;
    uint256 private constant MAX_TOTAL_SUPPLY = 0xFFFFFFFF;

    /**
     * Total supply exceeds maximum.
     */
    error ExceedsMaximumTotalSupply();

    /**
     * @dev Total amount of tokens with a given id.
     */
    function totalSupply(
        uint256 id
    ) public view virtual returns (uint256 _totalSupply) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, or(TOTAL_SUPPLY_STORAGE_OFFSET, shr(2, id)))
            _totalSupply := shr(shl(6, and(id, 0x03)), and(sload(keccak256(0x00, 0x20)), shl(shl(6, and(id, 0x03)), 0x00000000FFFFFFFF)))
        }
    }

    /**
     * @dev Sets total supply in custom storage slot location
     */
    function setTotalSupply(uint256 id, uint256 amount) private {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, or(TOTAL_SUPPLY_STORAGE_OFFSET, shr(2, id)))
            mstore(0x00, keccak256(0x00, 0x20))
            sstore(mload(0x00), or(and(not(shl(shl(6, and(id, 0x03)), 0x00000000FFFFFFFF)), sload(mload(0x00))), shl(shl(6, and(id, 0x03)), amount)))
        }
    }

    /**
     * @dev Total amount of tokens minted with a given id.
     */
    function totalMinted(
        uint256 id
    ) public view virtual returns (uint256 _totalMinted) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, or(TOTAL_SUPPLY_STORAGE_OFFSET, shr(2, id)))
            _totalMinted := shr(32, shr(shl(6, and(id, 0x03)), and(sload(keccak256(0x00, 0x20)), shl(shl(6, and(id, 0x03)), 0xFFFFFFFF00000000))))
        }
    }

    /**
     * @dev Sets total minted in custom storage slot location
     */
    function setTotalMinted(uint256 id, uint256 amount) private {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, or(TOTAL_SUPPLY_STORAGE_OFFSET, shr(2, id)))
            mstore(0x00, keccak256(0x00, 0x20))
            sstore(mload(0x00), or(and(not(shl(shl(6, and(id, 0x03)), 0xFFFFFFFF00000000)), sload(mload(0x00))), shl(shl(6, and(id, 0x03)), shl(32, amount))))
        }
    }

    /**
     * @dev Indicates whether any token exist with a given id, or not.
     */
    function exists(uint256 id) public view virtual returns (bool) {
        return totalSupply(id) > 0;
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
            uint256 supply = totalSupply(id);
            uint256 minted = totalMinted(id);
            unchecked {
                supply += amount;
                minted += amount;
            }
            if (supply > MAX_TOTAL_SUPPLY || minted > MAX_TOTAL_SUPPLY) {
                ERC1155P._revert(ExceedsMaximumTotalSupply.selector);
            }
            setTotalSupply(id, supply);
            setTotalMinted(id, minted);
        }

        if (to == address(0)) {
            uint256 supply = totalSupply(id);
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
            for (uint256 i = 0; i < ids.length; ) {
                uint256 id = ids[i];
                uint256 supply = totalSupply(id);
                uint256 minted = totalMinted(id);
                unchecked {
                    supply += amounts[i];
                    minted += amounts[i];
                    ++i;
                }
                if (supply > MAX_TOTAL_SUPPLY || minted > MAX_TOTAL_SUPPLY) {
                    ERC1155P._revert(ExceedsMaximumTotalSupply.selector);
                }
                setTotalSupply(id, supply);
                setTotalMinted(id, minted);
            }
        }

        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; ) {
                uint256 id = ids[i];
                uint256 supply = totalSupply(id);
                unchecked {
                    supply -= amounts[i];
                    ++i;
                }
                setTotalSupply(id, supply);
            }
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
