// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MultiSig} from "../src/Assignment4/Assignment4.sol";



contract Helper{
    uint public value;
    constructor(){
    }
    function updateValue(uint v) external{
        value = v;
    }
}

contract MultiSigTest is Test{
    MultiSig public wallet;
    address [] public ownersList;
    Helper public helper;

    /**
    Setup 5 accounts as owners
    set the required votes to execute = 3
    */
    function setUp() public{
        /*
        Going to keep a copy of ownersList in test for easy access to things like:
            ownersList.length
        w/o setting a getter function for the array's length in contract MultiSig
        */
        for (uint i = 1; i <= 5; i++){
            ownersList.push(vm.addr(i));
        }
        helper = new Helper();
        uint numReq = ownersList.length / 2 + 1;
        wallet = new MultiSig(ownersList, numReq);
    }

    function test() public{
        bytes memory payload1 = abi.encodeWithSignature("updateValue(uint256)", 100);
        deal(address(token), address(1), 1000 ether);
        vm.startPrank(address(1));
        uint amount = 100;
        bytes memory payload2 = abi.encodeWithSignature("transfer(address,uint256)", vm.addr(2), amount);
        (bool success, ) = address(helper).call(payload1);
        (bool success2, ) =address(token).call(payload2);
        require(success, "tx failed");
        require(success2, "tx failed");
        console.log(helper.value());
        console.log(token.balanceOf(address(1)));
        vm.stopPrank();
    }

    /***********************************************************************************************/
    /**Owners can submit tx**/
    /**submitTx(address _to, uint _value, bytes memory _data)**/

    /**
    Test submission of transactions by valid owners
    Verify that the propsed transactions have been logged
    */
    function test_submit_tx_by_owner() public{
        bytes memory payload;
        for(uint i = 0; i < ownersList.length; i++){
            vm.startPrank(wallet.ownersList(i));
            payload = abi.encodeWithSignature("updateValue(uint256)", i);
            wallet.submitTx(address(helper), 0, payload);
            vm.stopPrank();
        }
        assertEq(wallet.txCount(), ownersList.length);
    }
    /**
    submitTx() should fail if called by non-owner
    */
    function testFail_submit_tx_by_others() public{
        bytes memory payload;
        vm.startPrank(vm.addr(100));
        wallet.submitTx(address(helper), 0, payload);
        vm.stopPrank();
        assertEq(wallet.txCount(), 0);
    }

    /***********************************************************************************************/
    /**Owners can approve tx**/
    /**approveTx(uint _txId)**/

    /**
    Test approval of transactions by valid owners
    Verify the approval count has incremented and is correct
    */
    function test_approve_tx_by_owner() public{
        bytes memory payload;
        payload = abi.encodeWithSignature("updateValue(uint256)", 999);
        vm.prank(wallet.ownersList(0));
        uint txId = wallet.submitTx(address(helper), 0, payload);
        (,,,,,uint votesBefore,) = wallet.transactions(txId);
        vm.prank(wallet.ownersList(1));
        uint votes = wallet.approveTx(txId);
        (,,,,,uint votesAfter,) = wallet.transactions(txId);
        assertEq(votes, votesBefore+1);
        assertEq(2, votesAfter);
    }
    /**
    Test should fail if owner tries to approve twice
    */
    function testFail_approve_tx_by_owner_duplicate() public{
        bytes memory payload;
        payload = abi.encodeWithSignature("updateValue(uint256)", 999);
        vm.prank(wallet.ownersList(0));
        uint txId = wallet.submitTx(address(helper), 0, payload);
        vm.startPrank(wallet.ownersList(1));
        wallet.approveTx(txId);
        wallet.approveTx(txId);
        vm.stopPrank();
    }
    /**
    Test should fail if non-owner tries to approve
    */
    function testFail_approve_tx_by_others() public{
        bytes memory payload;
        payload = abi.encodeWithSignature("updateValue(uint256)", 999);
        vm.prank(wallet.ownersList(0));
        uint txId = wallet.submitTx(address(helper), 0, payload);
        vm.prank(vm.addr(999));
        wallet.approveTx(txId);
    }

    /***********************************************************************************************/
    /**executeTx(uint _txId)**/
    /**
    Transaction should automatically execute if required votes met
    Verify that tx is marked as executed in the MultiSig contract
    Verify that the transaction is actually executed:
        We'll use the example of calling updateValue(999) on helper
        check that the value in helper is actually updated to 999
    */
    function test_execute_tx_req_met() public{
        bytes memory payload;
        payload = abi.encodeWithSignature("updateValue(uint256)", 999);
        vm.prank(wallet.ownersList(0));
        uint txId = wallet.submitTx(address(helper), 0, payload);

        for(uint i = 1; i < wallet.numRequired(); i++){
            vm.startPrank(wallet.ownersList(i));
            wallet.approveTx(txId);
            vm.stopPrank();
        }
        (,,,bool executed,,uint votes,) = wallet.transactions(txId);
        assertEq(votes, wallet.numRequired());
        assertEq(executed, true);
        assertEq(helper.value(), 999);
    }
    /**
    Test fail if owner who hasn't voted yet tries to execute the tx a second time by voting after
        numRequirements met and tx executed
    */
    function testFail_execute_tx_again() public{
        bytes memory payload;
        payload = abi.encodeWithSignature("updateValue(uint256)", 999);
        vm.prank(wallet.ownersList(0));
        uint txId = wallet.submitTx(address(helper), 0, payload);

        for(uint i = 1; i <= wallet.numRequired(); i++){
            vm.startPrank(wallet.ownersList(i));
            wallet.approveTx(txId);
            vm.stopPrank();
        }
    }

    /***********************************************************************************************/
    /**Owners can cancel tx**/
    /**cancelTx(uint _txId)**/

    /**
    Cancel transaction by the proposer
    verify that the tx is set to cancelled
    */
    function test_cancel_tx_by_proposer() public{
        bytes memory payload;
        payload = abi.encodeWithSignature("updateValue(uint256)", 999);
        vm.startPrank(wallet.ownersList(0));
        uint txId = wallet.submitTx(address(helper), 0, payload);
        wallet.cancelTx(txId);
        vm.stopPrank();
        // (address to,uint value,,bool executed,address proposer,uint votes,bool canceled) = wallet.transactions(txId);
        (,,,,,,bool cancelled) = wallet.transactions(txId);
        assertEq(cancelled, true);
    }

    /**
    Cancel transaction by owner other than proposer should Fail
    */
    function testFail_cancel_tx_by_other() public{
        bytes memory payload;
        payload = abi.encodeWithSignature("updateValue(uint256)", 999);
        vm.prank(wallet.ownersList(0));
        uint txId = wallet.submitTx(address(helper), 0, payload);
        vm.prank(wallet.ownersList(1));
        wallet.cancelTx(txId);
        (,,,,,,bool cancelled) = wallet.transactions(txId);
        assertEq(cancelled, true);
    }
    

    /**
    Attempts to approve a cancelled transaction by an owner that hasn't voted yet should fail
    */
    function testFail_approve_cancelled_tx() public{
        bytes memory payload;
        payload = abi.encodeWithSignature("updateValue(uint256)", 999);
        vm.startPrank(wallet.ownersList(0));
        uint txId = wallet.submitTx(address(helper), 0, payload);
        wallet.cancelTx(txId);
        vm.stopPrank();
        (,,,,,,bool cancelled) = wallet.transactions(txId);
        assertEq(cancelled, true);
        vm.prank(wallet.ownersList(1));
        wallet.approveTx(txId);
    }
    
}