# Assignment 4
### Problem Description:
Develop a multi-signature wallet smart contract using Solidity. The contract should allow multiple
owners to collectively control the funds in the wallet. The key features include:

* A wallet with multiple owners, each having their own private key.

* A specified number of owners (threshold) is required to approve and execute a transaction.
Owners can submit, approve, and cancel transactions.

## Design
#### Submit
We can assume that the proposer who submitted the transaction would want to vote `YES` on his/her own proposal. So `approveTx(...)` is called within the `submitTx()` funciton.
#### Execution
I've made `executeTx()` an `internal` function. Instead of separately calling `execute` after the necessary approvals are gathered, we should just check if requirement is met within the `approveTx()` function and execute if it is.

```
    function approveTx(uint _txId) public onlyOwner txExists(_txId) notExecuted(_txId) notApproved(_txId) notCancelled(_txId)returns(uint){
        ...
        ...
        ...
        if (transactions[_txId].numVotes == numRequired){
            executeTx(_txId);
        }
        ...
    }
```
#### Cancellation
There are 2 ways we can do this. We can wipe the details of the transaction struct from the mapping, or we can mark the transaction as cancelled by toggling a member variable `bool cancelled` inside the struct.

I've went with the latter approach. This allows us to view the details of the proposed transactions and the votes it received even after cancellation.

We can also add an additional function if we want the ability to reinstate a cancelled transaction.
This is outside of the scope of requirements.
```
    function reinstateTx(uint _txId) public isProposer(_txId) txExists(_txId) notExecuted(_txId) isCancelled(_txId){
        transactions[_txId].cancelled = false;
    }
```

We also made the assumption that an owner can only cancel the transactions he/she had submitted, and not a transaction submitted by another owner.
