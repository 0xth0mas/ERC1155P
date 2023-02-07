// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./PixieJarsStoriesStructs.sol";
import "../interfaces/IPixieJarsStories.sol";
import "../interfaces/IPixieDust.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PixieJarsStoriesMinter is Ownable {

    error ArrayLengthMismatch();
    error InvalidRecipe();
    error InvalidRecipeUsage();
    error RecipeNotActive();
    error InsufficientPayment();

    MintRecipe[] private recipes;
    mapping(bytes32 => bool) private validRecipe;
    IPixieJarsStories public pixieJarsStories;
    IPixieDust public pixieDust;

    constructor(address _pixieJarsStories, address _pixieDust) {
        pixieJarsStories = IPixieJarsStories(_pixieJarsStories);
        pixieDust = IPixieDust(_pixieDust);
    }
    
    /**
     *   @dev mint function takes a given recipe, multiplier and user's proposed mint/burn token amounts
     *        and validates that it is a valid recipe and all parameters of the recipe are being followed.
     *        If the recipe is being followed, the token contract is called to mint and burn the specified
     *        tokens.
     */
    function mint(MintRecipe calldata recipe, uint256 recipeMultiplier, uint32 pixieDustCost, uint256[] calldata mintTokenIds, uint256[] calldata mintTokenQuantities, 
        uint256[] calldata burnTokenIds, uint256[] calldata burnTokenQuantities) external payable {

        //check recipe hash to ensure it is valid
        bytes32 recipeHash = keccak256(abi.encode(recipe));
        if(!validRecipe[recipeHash]) { revert InvalidRecipe(); }

        //check recipe to ensure it is active
        if(recipe.startTime > block.timestamp) { revert RecipeNotActive(); }
        if(recipe.endTime < block.timestamp) { revert RecipeNotActive(); }

        //validate array lengths match
        if(mintTokenIds.length != mintTokenQuantities.length) { revert ArrayLengthMismatch(); }
        if(burnTokenIds.length != burnTokenQuantities.length) { revert ArrayLengthMismatch(); }
        if(recipe.mintTokenIds.length != mintTokenIds.length) { revert InvalidRecipeUsage(); }
        if(recipe.burnTokenIds.length != burnTokenIds.length) { revert InvalidRecipeUsage(); }

        //check mint ids/quantities for compliance with recipe
        for(uint256 i = 0;i < mintTokenIds.length;) {
            if(recipe.mintTokenIds[i] != mintTokenIds[i]) { revert InvalidRecipeUsage(); }
            if((recipe.mintTokenQuantities[i] * recipeMultiplier) != mintTokenQuantities[i]) { revert InvalidRecipeUsage(); }
            unchecked {
                ++i;
            }
        }

        //check burn ids/quantities for compliance with recipe
        for(uint256 i = 0;i < burnTokenIds.length;) {
            if(recipe.burnTokenIds[i] != burnTokenIds[i]) { revert InvalidRecipeUsage(); }
            if((recipe.burnTokenQuantities[i] * recipeMultiplier) != burnTokenQuantities[i]) { revert InvalidRecipeUsage(); }
            unchecked {
                ++i;
            }
        }

        //check pixie dust to burn for compliance with recipe
        if(recipe.pixieDustCost > 0) {
            if((recipe.pixieDustCost * recipeMultiplier) != pixieDustCost) { revert InvalidRecipeUsage(); }
            uint256 totalPixieDustCost = uint256(pixieDustCost) * 10**18;
            pixieDust.burnDust(msg.sender, totalPixieDustCost);
        }

        //calculate mint cost, refund if overpayment sent
        uint256 totalCost = uint256(recipe.cost) * 1 gwei * recipeMultiplier;
        refundIfOver(totalCost);

        //single token mint if token id length is 1, batch mint if more than 1
        if(mintTokenIds.length == 1) {
            pixieJarsStories.mint(msg.sender, mintTokenIds[0], mintTokenQuantities[0]);
        } else if(mintTokenIds.length > 1) {
            pixieJarsStories.mintBatch(msg.sender, mintTokenIds, mintTokenQuantities);
        }

        //single token burn if token id length is 1, batch mint if more than 1
        if(burnTokenIds.length == 1) {
            pixieJarsStories.burn(msg.sender, burnTokenIds[0], burnTokenQuantities[0]);
        } else if(burnTokenIds.length > 1) {
            pixieJarsStories.burnBatch(msg.sender, burnTokenIds, burnTokenQuantities);
        }
    }

    /**
     *   @dev returns an array of active recipes that can be submitted for minting
     */
    function getActiveRecipes() external view returns(MintRecipe[] memory activeRecipes) {
        MintRecipe[] memory tmpRecipes = new MintRecipe[](recipes.length);
        uint256 activeCount;
        bytes32 recipeHash;
        for(uint256 i = 0;i < recipes.length;) {
            MintRecipe memory tmpRecipe = recipes[i];
            if(tmpRecipe.startTime < block.timestamp) {
                if(tmpRecipe.endTime > block.timestamp) {
                    recipeHash = keccak256(abi.encode(tmpRecipe));
                    if(validRecipe[recipeHash]) {
                        tmpRecipes[activeCount] = tmpRecipe;
                        unchecked {
                            activeCount++;
                        }
                    }
                }
            }
            unchecked {
                ++i;
            }
        }
        
        activeRecipes = new MintRecipe[](activeCount);
        for(uint256 i = 0;i < activeCount;) {
            activeRecipes[i] = tmpRecipes[i];
            unchecked {
                ++i;
            }
        }
    }    

    /**
     *   @dev Administrative function to add a new recipe to define token minting and burning parameters, time window and costs
     */
    function addRecipe(uint32 cost, uint32 startTime, uint32 endTime, uint32 pixieDustCost, uint256[] calldata mintTokenIds,
        uint256[] calldata mintTokenQuantities, uint256[] calldata burnTokenIds, uint256[] calldata burnTokenQuantities) external onlyOwner {
        if(mintTokenIds.length != mintTokenQuantities.length) { revert ArrayLengthMismatch(); }
        if(burnTokenIds.length != burnTokenQuantities.length) { revert ArrayLengthMismatch(); }
        if(mintTokenIds.length == 0 && burnTokenIds.length == 0) { revert InvalidRecipe(); }

        MintRecipe memory newRecipe;

        newRecipe.cost = cost;
        newRecipe.startTime = startTime;
        newRecipe.endTime = endTime;
        newRecipe.pixieDustCost = pixieDustCost;
        newRecipe.mintTokenIds = mintTokenIds;
        newRecipe.mintTokenQuantities = mintTokenQuantities;
        newRecipe.burnTokenIds = burnTokenIds;
        newRecipe.burnTokenQuantities = burnTokenQuantities;

        bytes32 recipeHash = keccak256(abi.encode(newRecipe));
        validRecipe[recipeHash] = true;
        recipes.push(newRecipe);
    }

    /**
     *   @dev Administrative function to enable and disable a recipe if necessary outside of its time limit settings
     */
    function setRecipeValid(MintRecipe calldata recipe, bool valid) external onlyOwner {
        bytes32 recipeHash = keccak256(abi.encode(recipe));
        validRecipe[recipeHash] = valid;
    }

    /**
     *   @dev If msg.value exceeds calculated payment for mint transaction, refunds the overage back to msg.sender
     */
    function refundIfOver(uint256 price) private {
        if(msg.value < price) { revert InsufficientPayment(); }
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    /**
     *   @dev Withdraws minting funds from contract
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}