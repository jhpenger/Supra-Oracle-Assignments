// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TokenSale} from "../src/Assignment1/Assignment1.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20{
    constructor(string memory name, string memory symbol)ERC20(name,symbol){
        
    }
}

contract TokenSaleTest is Test{
    TokenSale public ico;
    address public user1;
    address public user2;
    address public tokenAddr;
    IERC20 public token;

    /**We will keep a copy of presale & publicSale here instead of using getter functions
    it'll be much easier since the struct sale has way too many things inside
    and since we will only use it to refrence setup parameters and dont care about the state
    */
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
    Sale public presale;
    Sale public publicSale;

    /**
    Setup test a user and pre-deal it with 100k ether
    issues:
        std deal for erc20 tokens in setup wont persist, will use modifier below to deal out
     */
    function setUp() public {
        user1 = vm.addr(1);
        token = new MyToken('My Token', 'MTK');
        tokenAddr = address(token);
        deal(user1, 100000 ether);
        vm.warp(100);
        presale = Sale(10 ether, 100 ether, 0, 0, 0.5 ether, 5 ether, 8, block.timestamp, block.timestamp+1000);
        publicSale = Sale(10 ether, 1000 ether, 0, 0, 1 ether, 10 ether, 5, presale.end+1, presale.end + 1001);
        ico = new TokenSale(tokenAddr,
                                presale.minCap,
                                presale.maxCap,
                                presale.minPerUser,
                                presale.maxPerUser,
                                presale.exchangeRate,
                                presale.start,
                                presale.end);
        ico.setPublicSale(publicSale.minCap, publicSale.maxCap, 
                            publicSale.minPerUser, publicSale.maxPerUser, 
                            publicSale.exchangeRate, 
                            publicSale.start, publicSale.end);
    }

    //Deal tokens to the Sale Contract
    modifier dealTokensToContract(uint amt){
        deal(address(token), address(ico), amt * 1e18);
        _;
    }

    /***********************************************************************************************/
    /**Pre Sale**/
    /**
    Conditions to satisfy:
        1. Users can buy during the specified time period
        2. The presale has a maximum cap on the total Ether that can be raised.
        3. The presale has a minimum and maximum contribution limit per participant.
        4. Tokens are distributed immediately upon contribution.
     */
    /*
    Presale:
    Buy during valid presale time
    using user1 to execute, who's been pre dealt 1000 eth
    testFail*:
        make sure buy fails when buyPresale() is called outside of the valid time period
    */
    function test_fuzz_presale_buy_during_period(uint timestamp) public dealTokensToContract(presale.maxCap){
        vm.assume(timestamp >= presale.start && timestamp <= presale.end);
        vm.warp(timestamp);
        vm.prank(user1);
        ico.buyPresale{value: presale.minPerUser}();
    }
    function testFail_fuzz_presale_buy_during_period(uint timestamp) public dealTokensToContract(presale.maxCap){
        vm.assume(timestamp < presale.start || timestamp > presale.end);
        vm.warp(timestamp);
        vm.prank(user1);
        ico.buyPresale{value: presale.minPerUser}();
    }

    /**
    Presale:
    Buy presale adhering to minimum and maximum contribution rules per user
    testFail*:
        test to make sure fail when inverse of above conditions are inputed
     */
    function test_fuzz_presale_buy_allowed_amounts(uint amt) public dealTokensToContract(presale.maxCap){ 
        vm.assume(amt >= presale.minPerUser && amt <= presale.maxPerUser);
        vm.warp(presale.start);
        vm.prank(user1);
        ico.buyPresale{value: amt}();
    }
    function testFail_fuzz_presale_buy_allowed_amounts(uint amt) public dealTokensToContract(presale.maxCap){ 
        vm.assume(amt < presale.minPerUser || amt > presale.maxPerUser);
        vm.warp(presale.start);
        vm.prank(user1);
        ico.buyPresale{value: amt}();
    }

    /**
    Presale:
    check if tokens are distributed in correct amount & immediately after contribution
    testFail*:
        fail if buying incorrect amount
     */
    function test_fuzz_presale_immediate_distribution(uint amt) public dealTokensToContract(presale.maxCap){
        vm.assume(presale.minPerUser <= amt  && amt <= presale.maxPerUser);
        vm.warp(presale.start);
        vm.prank(user1);
        ico.buyPresale{value: amt}();
        assertEq(amt * presale.exchangeRate, token.balanceOf(user1));
    }
    function testFail_fuzz_presale_immediate_distribution(uint amt) public dealTokensToContract(presale.maxCap){
        vm.assume(presale.minPerUser > amt  || amt > presale.maxPerUser);
        vm.warp(presale.start);
        vm.prank(user1);
        ico.buyPresale{value: amt}();
        assertEq(0, token.balanceOf(user1));
    }

    /**
    Presale:
    check when user make multiple buys in sequence until max/user contribution limit reached
    */
    function test_fuzz_presale_multi_buys(uint numBuys) public dealTokensToContract(presale.maxCap){
        vm.assume(numBuys <= presale.maxPerUser / presale.minPerUser && numBuys >0);
        uint amt = presale.maxPerUser / numBuys;
        if (amt >= presale.minPerUser){
            vm.warp(presale.start);
            vm.startPrank(user1);
            for (uint i = 0; i < numBuys; i++){
                ico.buyPresale{value: amt}();
            }
            vm.stopPrank();
        }
        //divisions may cause rounding errors, don't use following assert
        // assertEq(presale.maxPerUser * presale.exchangeRate, token.balanceOf(user1));
    }
    function testFail_presale_multi_buys(uint amt) public dealTokensToContract(presale.maxCap){
        vm.assume(amt > 0);
        vm.warp(presale.start);
        vm.startPrank(user1);
        ico.buyPresale{value: presale.maxPerUser}();
        ico.buyPresale{value: amt}();
        vm.stopPrank();
    }

    /***********************************************************************************************/



    /**
    Public Sale:
    Buy during valid sale time
    testFail*:
        fail if attempt buy outside of sale time
     */
    function test_fuzz_publicSale_buy_during_period(uint timestamp) public dealTokensToContract(publicSale.maxCap){
        vm.assume(timestamp >= publicSale.start && timestamp <= publicSale.end);
        vm.warp(timestamp);
        vm.prank(user1);
        ico.buyPublicSale{value: publicSale.minPerUser}();
    }
    function testFail_fuzz_publicSale_buy_during_period(uint timestamp) public dealTokensToContract(publicSale.maxCap){
        vm.assume(timestamp < publicSale.start || timestamp > publicSale.end);
        vm.warp(timestamp);
        vm.prank(user1);
        ico.buyPublicSale{value: publicSale.minPerUser}();
    }

    /**
    Public Sale:
    Buy public sale adhering to minimum and maximum contribution rules per user
    testFail*:
        test to make sure fail when inverse of above conditions are inputed
     */
    function test_fuzz_publicSale_buy_allowed_amounts(uint amt) public dealTokensToContract(publicSale.maxCap){ 
        vm.assume(amt >= publicSale.minPerUser && amt <= publicSale.maxPerUser);
        vm.warp(publicSale.start);
        vm.prank(user1);
        ico.buyPublicSale{value: amt}();
    }
    function testFail_fuzz_publicSale_buy_allowed_amounts(uint amt) public dealTokensToContract(publicSale.maxCap){ 
        vm.assume(amt < publicSale.minPerUser || amt > publicSale.maxPerUser);
        vm.warp(publicSale.start);
        vm.prank(user1);
        ico.buyPublicSale{value: amt}();
    }

    /**
    Public Sale:
    check if tokens are distributed in correct amount & immediately after contribution
    testFail*:
        fail if buying incorrect amount
     */
    function test_fuzz_publicSale_immediate_distribution(uint amt) public dealTokensToContract(publicSale.maxCap){
        vm.assume(publicSale.minPerUser <= amt  && amt <= publicSale.maxPerUser);
        vm.warp(publicSale.start);
        vm.prank(user1);
        ico.buyPublicSale{value: amt}();
        assertEq(amt * publicSale.exchangeRate, token.balanceOf(user1));
    }
    function testFail_fuzz_publicSale_immediate_distribution(uint amt) public dealTokensToContract(publicSale.maxCap){
        vm.assume(publicSale.minPerUser > amt  || amt > publicSale.maxPerUser);
        vm.warp(publicSale.start);
        vm.prank(user1);
        ico.buyPublicSale{value: amt}();
        assertEq(0, token.balanceOf(user1));
    }

    /**
    Public Sale:
    check when user make multiple buys in sequence until max/user contribution limit reached
    */
    function test_fuzz_publicSale_multi_buys(uint numBuys) public dealTokensToContract(publicSale.maxCap){
        vm.assume(numBuys <= publicSale.maxPerUser / publicSale.minPerUser && numBuys >0);
        uint amt = publicSale.maxPerUser / numBuys;
        if (amt >= publicSale.minPerUser){
            vm.warp(publicSale.start);
            vm.startPrank(user1);
            for (uint i = 0; i < numBuys; i++){
                ico.buyPublicSale{value: amt}();
            }
            vm.stopPrank();
        }
    }
    function testFail_publicSale_multi_buys(uint amt) public dealTokensToContract(publicSale.maxCap){
        vm.assume(amt > 0);
        vm.warp(publicSale.start);
        vm.startPrank(user1);
        ico.buyPublicSale{value: publicSale.maxPerUser}();
        ico.buyPublicSale{value: amt}();
        vm.stopPrank();
    }


    /***********************************************************************************************/
    /**Token Distribution**/
    /**
    Make sure only owner can call distributeTokens()
    other functionalities should be handled by the erc20 token itself
     */
    function test_token_distribution() public dealTokensToContract(500 ether){
        ico.distributeTokens(user1, 1 ether);
    }
    function testFail_token_distribution() public dealTokensToContract(500 ether){
        vm.prank(user1);
        ico.distributeTokens(user1, 1 ether);
    }

    /***********************************************************************************************/
    /**Refund Presale**/

    /**
    Users should be able to call refund if presale goal not reached:
        Defined the total raised amount as (min target)/2
        Loop through an array of wallets to buy the presale ->
        Set blocktime to after presale end time ->
        loop through the wallets again to call refund:
            use fuss to test valid refund values up to maximum allowed refund
        ->
        check to verify correct amount of eth is refunded
     */
    function test_fuzz_presale_refund_if_not_target(uint refundTokensAmt) public dealTokensToContract(presale.maxCap){ 
        uint totalAmt = presale.minCap / 2;
        uint acctFunding = presale.minPerUser;
        vm.assume(refundTokensAmt <= acctFunding * presale.exchangeRate);
        address[] memory accounts = new address[](uint(totalAmt/presale.minPerUser) );
        address acct;
        for (uint i = 1; presale.totalRaised < totalAmt; i++){
            accounts[i-1] = vm.addr(i);
            vm.startPrank(vm.addr(i));
            deal(vm.addr(i), acctFunding);
            presale.totalRaised += acctFunding;
            ico.buyPresale{value: acctFunding}();
            vm.stopPrank();
        }
        vm.warp(presale.end+1);
        for (uint i = 0; i < accounts.length; i++){
            acct = accounts[i];
            vm.startPrank(acct);
            token.approve(address(ico), refundTokensAmt);
            ico.refundPresale(refundTokensAmt);
            vm.stopPrank();
            assertEq(acct.balance, refundTokensAmt / presale.exchangeRate);
            assertEq(token.balanceOf(acct), acctFunding*presale.exchangeRate - refundTokensAmt);
        }
    }

    /*
    If presale target reached, don't allow refunds
    */
    function testFail_presale_refund_if_target() public dealTokensToContract(presale.maxCap){ 
        uint totalAmt = presale.minCap;
        uint acctFunding = presale.minPerUser;
        address[] memory accounts = new address[](uint(totalAmt/presale.minPerUser) );
        address acct;
        for (uint i = 1; presale.totalRaised < totalAmt; i++){
            accounts[i-1] = vm.addr(i);
            vm.startPrank(vm.addr(i));
            deal(vm.addr(i), acctFunding);
            presale.totalRaised += acctFunding;
            ico.buyPresale{value: acctFunding}();
            vm.stopPrank();
        }
        vm.warp(presale.end+1);
        for (uint i = 0; i < accounts.length; i++){
            acct = accounts[i];
            vm.startPrank(acct);
            token.approve(address(ico), token.balanceOf(acct));
            ico.refundPresale(token.balanceOf(acct));
            vm.stopPrank();
        }
    }

    /***********************************************************************************************/
    /**Refund Public Sale**/
    /**
    Users should be able to call refund if public sale goal not reached:
        Defined the total raised amount as (min target)/2
        Loop through an array of wallets to buy the publicSale ->
        Set blocktime to after public sale end time ->
        loop through the wallets again to call refund:
            use fuss to test valid refund values up to maximum allowed refund
        ->
        check to verify correct amount of eth is refunded
     */
    function test_fuzz_publicSale_refund_if_not_target(uint refundTokensAmt) public dealTokensToContract(publicSale.maxCap){ 
        uint totalAmt = publicSale.minCap / 2;
        uint acctFunding = publicSale.minPerUser;
        vm.assume(refundTokensAmt <= acctFunding * publicSale.exchangeRate);
        address[] memory accounts = new address[](uint(totalAmt/publicSale.minPerUser) );
        address acct;
        vm.warp(publicSale.start);
        for (uint i = 1; publicSale.totalRaised < publicSale.minCap / 2; i++){
            accounts[i-1] = vm.addr(i);
            vm.startPrank(vm.addr(i));
            deal(vm.addr(i), acctFunding);
            publicSale.totalRaised += acctFunding;
            ico.buyPublicSale{value: acctFunding}();
            vm.stopPrank();
        }
        vm.warp(publicSale.end+1);
        for (uint i = 0; i < accounts.length; i++){
            acct = accounts[i];
            vm.startPrank(acct);
            token.approve(address(ico), refundTokensAmt);
            ico.refundPublicSale(refundTokensAmt);
            vm.stopPrank();
            assertEq(acct.balance, refundTokensAmt / publicSale.exchangeRate);
        }
    }

    /*
    If public sale target reached, don't allow refunds
    */
    function testFail_publicSale_refund_if_target() public dealTokensToContract(publicSale.maxCap){ 
        uint totalAmt = publicSale.minCap;
        uint acctFunding = publicSale.minPerUser;
        address[] memory accounts = new address[](uint(totalAmt/publicSale.minPerUser) );
        address acct;
        vm.warp(publicSale.start);
        for (uint i = 1; publicSale.totalRaised < totalAmt; i++){
            accounts[i-1] = vm.addr(i);
            vm.startPrank(vm.addr(i));
            deal(vm.addr(i), acctFunding);
            publicSale.totalRaised += acctFunding;
            ico.buyPublicSale{value: acctFunding}();
            vm.stopPrank();
        }
        vm.warp(publicSale.end+1);
        for (uint i = 0; i < accounts.length; i++){
            acct = accounts[i];
            vm.startPrank(acct);
            token.approve(address(ico), token.balanceOf(acct));
            ico.refundPublicSale(token.balanceOf(acct));
            vm.stopPrank();
        }
    }


}