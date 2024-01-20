# Assignment 2
### Problem Description:
Design a decentralized voting system smart contract using Solidity. The contract should support the
following features:
* Users can register to vote.
* The owner of the contract can add candidates.
* Registered voters can cast their votes for a specific candidate.
* The voting process should be transparent, and the results should be publicly accessible.

## Design
Will create 2 structs to define a voter, and the other to define a candidate.
```
    struct Voter{
        bool registered;
        bool voted;
        bool choice;
    }
```
```
    struct Candidate{
        bool onBallot;
        uint votes;
    }
```
We will use a `mapping` to store the candidates and use an array to keep track of the full list of candidates so we can later loop through it the check for winner.
```
    mapping(address => Candidate) public candidates;
    address[] public candidatesList;
```
Instructions did not say we need to keep track of the number of registered voters or who they are. As such we'll just use a mapping and not add an array.
```
  mapping(address => Voter) public voters;
```
If we want to add the ability to check for the number of voters who have voted/# of those who have not voted, or if we want to calculate the % of votes a candidate has received, then we can add an array to keep track of the list of voters.

#### Registration & Vote
The requirement that a voter must register to vote is kind of unnecessary since there are no restrictions given on who can register or when a user can register.
It would be much more reasonable to just assume any user who wishes to vote is "registered" upon casting a vote. This means the voter don't have to call 2 separate functions, `register()` & `vote()`, just to vote.

However, we'll stick to the requirements and make 2 separate functions.
```
    function registerToVote() external{
        voters[msg.sender].registered = true;
        emit NewVoterRegistration(msg.sender);
    }
```
```
    function vote(address candidate) external voterRegistered voterEligible candidateEligible(candidate){
        voters[msg.sender].voted = true;
        candidates[candidate].votes++;
        emit NewVote(msg.sender, candidate);
    }
```

#### Election Result
I've added a function inside the smart contract for retrieving the winner of the election at a specific time.
```
    function getElectionResult() external view returns(address, uint){
        uint maxVotes;
        address currentWinner;
        for (uint i = 0; i < candidatesList.length; i++){
            if (candidates[candidatesList[i]].votes > maxVotes){
                maxVotes = candidates[candidatesList[i]].votes;
                currentWinner = candidatesList[i];
            }
        }
        return (currentWinner, maxVotes);
    }
```
Since the instruction did not specify restrictions on when and if voter/candidate registration will end, nor did it stipulate if we should set an end period to the voting process, it is possible the result will change over time.
New voters will be able to register and vote, new candidates can possibly be added, all of which will alter the result. In other words, the instructions given are for a "rolling" election that doesn't end.

Ideally, to minimize cost, we should calculate the result of the election using something like javascript by retrieving the public state variables instead of making the calculations on chain.
I've simply added the function in the smart contract for reference.
