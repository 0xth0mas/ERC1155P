![](https://github.com/0xth0mas/ERC1155P/blob/main/media/ERC1155P.png?raw=true)
by [0xth0mas](http://twitter.com/justadev "0xth0mas")

## About The Project
The goal of ERC1155P is to provide a fully compliant implementation of the EIP-1155 standard with significant gas savings for collectors minting, buying and transferring multiple tokens in a collection and open up new possibilities for creators. 

ERC1155P accomplishes this by packing token balance and mint data for 8 tokens into a single storage slot - giving each token 16 bits for its individual token balance and 16 bits for the number minted - and various other optimizations including custom storage pointer locations and use of assembly logic to produce more gas efficient operations.

ERC1155P includes an extension - ERC1155PSupply - that applies similar balance packing and storage optimizations for projects that have use for the totalSupply function.

## Example Gas Savings

#### OpenSea sale of 7 tokens from 3 different owners
ERC1155P Gas Used: 597,364:
https://goerli.etherscan.io/tx/0xb9867ef727010e004073803506cb5d36600f3c0183f62e37ea090eabd385c1c6

ERC1155 Gas Used: 848,172
https://etherscan.io/tx/0x67573b9dc0cfa08abd4e78fc13d248869e7424caa4837a3c418b2d57ad2f7e72 

#### Batch transfer of 7 tokens through OpenSea transfer helper
ERC1155P Gas Used: 127,335
https://goerli.etherscan.io/tx/0xf49c3ad6c434ce0dcb357be0a87a1e81f3875592a771e6928ae73925fcb4cc00

ERC1155 Gas Used: 318,556
https://etherscan.io/tx/0xbb2d61a52d9dd5ae454a442baf3acd09d4206f81a0457deb601d95b906d0ecf3

#### Burn 1 token to mint 1 token
ERC1155P Gas Used: 62,574
https://goerli.etherscan.io/tx/0xa9603d4cae42baa29a99921c6496e7e9179388a84ee1087f40458de39958aea2

Manifold ERC1155 Gas Used: 149,157
https://etherscan.io/tx/0xdc4ce233bc3ced649e8525c61cac00b553c5ebc75a1c7a62a34a38548ca8022a

## Testing
ERC1155P was tested using 35,000 event logs from an Ethereum ERC1155 collection run through a Hardhat test script. The final balance data was compared against a snapshot of the token balances from Alchemy, off-chain analysis of the 35,000 event logs to validate the Alchemy snapshot, and an execution of the logs through a standard ERC1155 contract in Hardhat. All data sets were verified to be exact matches prior to release. The test data and scripts can be found in the /tests folder linked below.

https://github.com/0xth0mas/ERC1155P/tree/main/tests

## Known Limitations
**Maximum Token ID:** The custom storage pointer locations for account/token balances use a combination of an offset number, the wallet address and token bucket number (tokens 0-7 are in bucket 0, 8-15 are in bucket 1, etc). The offset uses 4 bits and wallet address uses 160 bits of the 256 bit storage pointer leaving 92 bits for token buckets. With 8 tokens in each bucket the maximum token id is 2^95-1.

**Maximum Account/Token Balance:** Each account/token balance is limited to 16 bits of data which restricts maximum token balance for a single wallet/token combination to 65,535.

**Maximum Total Supply:** ERC1155PSupply utilizes storage packing for the totalSupply of each token in a similar way to the account/token balances except it packs 4 tokens into one storage slot instead of 8 tokens. This allows for a maximum totalSupply of a single token to be 2^32-1, or approximately 4.3B.


## License

Distributed under the MIT License. See `LICENSE.md` for more information.


## Contact

- 0xth0mas (owner) - [@0xjustadev](https://twitter.com/0xjustadev)
