# Assignment 3
### Problem Description:
Create a smart contract that facilitates the swapping of one ERC-20 token for another at a predefined
exchange rate. The smart contract should include the following features:
* Users can swap Token A for Token B and vice versa.
* The exchange rate between Token A and Token B is fixed.
* Implement proper checks to ensure that the swap adheres to the exchange rate.
* Include events to log swap details.

## Design
We'll use a struct to keep track of details about the swap pair
```
    struct SwapPair{
        IERC20 tokenA;
        IERC20 tokenB;
        uint exchangeRate;
    }
```
We're going to assume that only the owner will be contributing to the liquidity of such a swap, since the instructions didn't specify who can pull out liquidity we'll just assume it's restricted to the owner; thus, it wouldn't make sense for anyone besides the owner to contribute, although they could.
Following the above thinking, we'll also have 2 functions for the owner to pull out liquidity.
```
    function withdrawA() external onlyOwner{
        pair.tokenA.transfer(owner(), pair.tokenA.balanceOf(address(this)));
    }
    function withdrawB() external onlyOwner {
        pair.tokenB.transfer(owner(), pair.tokenB.balanceOf(address(this)));
    }
```
