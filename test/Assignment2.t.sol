// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedVotingSystem} from "../src/Assignment2/Assignment2.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VotingTest is Test{

    DecentralizedVotingSystem public system;
    address public user1;
    address public candidate1;
    function setUp() public{
        system = new DecentralizedVotingSystem();
        user1 = vm.addr(1);
        candidate1 = vm.addr(2);
    }

    /***********************************************************************************************/
    /**REGISTER TO VOTE**/
    /**
    Users can register to vote:
        check that voter's registered status is updated to true after registration
     */
    function test_fuzz_register_new_voter(address voter) public{
        vm.prank(voter);
        system.registerToVote();
        (bool registered, , ) = system.voters(voter);
        assertEq(registered, true);
    }
    function testFail_fuzz_register_new_voter(address voter) public{
        vm.prank(voter);
        (bool registered, , ) = system.voters(voter);
        assertEq(registered, true);
    }

    /***********************************************************************************************/
    /**ADDING CANDIDATES**/
    /**
    The owner of the contract can add candidates:
    addCandidate(address _)
     */
    /**
    Add candidate by owner
     */
    function test_fuzz_add_candidate(address candidate) public{
        system.addCandidate(candidate);
        (bool onBallot,) = system.candidates(candidate);
        assertEq(onBallot, true);
     }

    /**
    Add candidate by other wallets
     */
    function testFail_fuzz_add_candidate(address candidate) public{
        vm.prank(vm.addr(1));
        system.addCandidate(candidate);
        (bool onBallot,) = system.candidates(candidate);
        assertEq(onBallot, true);
     }

    /***********************************************************************************************/
    /**VOTING**/
    /**
    Registered voters can cast their votes for a specific candidate:
    vote(address candidate)
     */
    /**
    Vote for a valid candidate (on ballot) for the first time
     */
    function test_vote_valid_candidate() public{
        system.addCandidate(candidate1);
        vm.startPrank(user1);
        system.registerToVote();
        system.vote(candidate1);
        vm.stopPrank();
        (bool onBallot,uint votes) = system.candidates(candidate1);
        assertEq(onBallot, true);
        assertEq(votes, 1);
    }

    /*
    Fail if voting for second time (ie. changing vote)
    */
    function testFail_change_vote_valid_candidate() public{
        system.addCandidate(candidate1);
        system.addCandidate(vm.addr(3));
        vm.startPrank(user1);
        system.registerToVote();
        system.vote(candidate1);
        system.vote(vm.addr(3));
        vm.stopPrank();
    }
    /**
    Fail if voting for ineligible candidates (not on ballot)
    */
    function testFail_vote_bad_candidate() public{
        vm.startPrank(user1);
        system.registerToVote();
        system.vote(candidate1);
        vm.stopPrank();
    }
    /**
    Fail if voting but not registered to vote
     */
    function testFail_vote_not_registered() public{
        system.addCandidate(candidate1);
        vm.startPrank(user1);
        system.vote(candidate1);
        vm.stopPrank();
    }


    function test_result() public{
        system.addCandidate(candidate1);
        system.addCandidate(vm.addr(3));
        vm.startPrank(user1);
        system.registerToVote();
        system.vote(candidate1);
        vm.stopPrank();
        (address winner, uint votes) = system.getElectionResult();
        assertEq(winner, candidate1);
        assertEq(votes, 1);
    }

}