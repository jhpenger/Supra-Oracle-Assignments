# Assignment 1
### Problem Description:
Create a token sale smart contract for a new blockchain project. The token sale will be conducted in
two phases: a presale and a public sale. The smart contract should be able to handle the following
functionalities:
#### Presale:
* Users can contribute Ether to the presale and receive project tokens in return.
* The presale has a maximum cap on the total Ether that can be raised.
* The presale has a minimum and maximum contribution limit per participant.
* Tokens are distributed immediately upon contribution.
#### Public Sale:
* After the presale ends, the public sale begins.
* Users can contribute Ether to the public sale and receive project tokens in return.
* The public sale has a maximum cap on the total Ether that can be raised.
* The public sale has a minimum and maximum contribution limit per participant.
* Tokens are distributed immediately upon contribution.
#### Token Distribution:
*The smart contract should have a function to distribute project tokens to a specified
address. This function can only be called by the owner of the contract.
#### Refund:
*If the minimum cap for either the presale or public sale is not reached, contributors
should be able to claim a refund.
## Design Choices
There are 2 ways we can approach this.
#### Approach 1
Set up a contract that solely deals with the sale of the tokens (ie. accepting payments from contributors, and distributing the tokens)
#### Approach 2
Set up an ERC20 contract that has the sale functionality built into the token contract. In this method, tokens will be distributed to contributors by directly calling the token contract's `_mint()` function.

I'll use **Approach 1** for the assignment. Since **Approach 2** limits the reusability, we can think of it like an ICO where the sale is set up once during creation, and this approach limits who can set up the token sale (only the owner of the token).

**Approach 1**, on the other hand, lets anyone possessing some amount of any ERC20 token to setup a sale. Sales can also be setup multiple times by simply redeploying the contract.
However, when using **Approach 1** there is a possibility that the owner of the sale contract didn't fund enough tokens into the contract to satisfy the max cap of the sales.
And given that the instruction says `owner` should have access to a `distributeToken()` function, the `owner` will also be able to end a sale prematurely by withdrawing all tokens in the contract through calling the `distributeToken()` to distribute to himself.

We will create 2 structs in our contract, one to keep track of the properties of a sale:
```
    struct Sale{
        uint minCap;
        uint maxCap;
        uint totalRaised;
        uint balance;
        uint minPerUser;
        uint maxPerUser;
        uint exchangeRate;
        uint start;
        uint end;
    }
```
the other will contain the properties associated with a contributor:
```
    struct User{
        uint presaleETHSent;
        uint presaleTokensBought;
        uint publicSaleETHSent;
        uint publicSaleTokensBought;
    }
```
the `User` struct is necessary to keep track of `eth` contributed and `tokens` received in the event we need to process a refund in the future.

#### Distribution and Refund
The assignment's instructions specified that tokens should be distributed immediately upon contribution. This implies that the users are allowed to keep the tokens instead even if the sale target was not reached.
Following this logic, we should also allow the users to do a partial refund, instead of a full refund, if they so choose.

#### Owner's withdraw
There was no instruction on when the owner can withdraw `eth` from the contract.

I've decided to let the owner withdraw `eth` from a sale as soon as that specific sale's (either public or presale) minimum cap is reached.
The owner will be able to withdraw incrementally as more `eth` pours in, up until the max cap is reached.

In the case of a refund, there will be iliquid `eth` locked up in the contract that hasn't been claimed yet. The contributors have the full benefit of a liquid token, since tokens are distributed immediately upon contribution rather than when the sale ends successfully, and they can freely use the tokens as they see fit until they decide to call the refund. Meanwhile, the `eth` in the contract will be in limbo.
This can cause interesting scenarios, where a contributor to a failed sale can sell the tokens on a swap immediately after the distribution, enjoy the full benefit of the liquidity from the `eth` they received from the swap sale without calling refund. Then, if the token price crashes in the future, buy back for a fraction of the cost and call refund on the contract for a huge profit.

#### Issues with the constructor
Since there are 2 sales stipulated in the instructions. There are a lot of  parameters we need to pass to the constructor to set up the contract. However, there are way too many params, causing `stack too deep` error since solidity restricts the space allocated for the parameters of the constructor (assume it's to avoid possible overflow attacks).

I've decided to only pass the params associated with the presale to the constructor. The `owner` will have to separately call `setPublicSale()` after contract creation.
