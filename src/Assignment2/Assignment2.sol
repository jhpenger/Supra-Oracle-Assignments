pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizedVotingSystem is Ownable{
    struct Voter{
        bool registered;
        bool voted;
        bool choice;
    }
    mapping(address => Voter) public voters;

    struct Candidate{
        bool onBallot;
        uint votes;
    }
    mapping(address => Candidate) public candidates;
    address[] public candidatesList;

    event NewVoterRegistration(address indexed voter);
    event NewCandidateRegistration(address indexed candidate);
    event NewVote(address indexed voter, address indexed candidate);


    constructor() Ownable(msg.sender){
    }

    modifier voterRegistered(){
        require(voters[msg.sender].registered, "Register first to vote");
        _;
    }
    modifier voterEligible(){
        require(!voters[msg.sender].voted, "You've already voted");
        _;
    }
    modifier candidateEligible(address candidate){
        require(candidates[candidate].onBallot, "Your chosen candidate is not on the ballot");
        _;
    }
    
    function registerToVote() external{
        voters[msg.sender].registered = true;
        emit NewVoterRegistration(msg.sender);
    }

    function addCandidate(address newCandidate) external onlyOwner{
        candidates[newCandidate].onBallot = true;
        candidatesList.push(newCandidate);
        emit NewCandidateRegistration(newCandidate);
    }

    function vote(address candidate) external voterRegistered voterEligible candidateEligible(candidate){
        voters[msg.sender].voted = true;
        candidates[candidate].votes++;
        emit NewVote(msg.sender, candidate);
    }
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

}