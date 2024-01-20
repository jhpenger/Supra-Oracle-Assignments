// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TokenSwap} from "../src/Assignment3/Assignment3.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20{
    constructor(string memory name, string memory symbol)ERC20(name,symbol){
        
    }
}

contract SwapTest is Test{
    TokenSwap public swap;
    address public user1;
    IERC20 public tokenA;
    IERC20 public tokenB;
    uint public rate;
    function setUp() public{
        tokenA = new MyToken('Token A', 'TKA');
        tokenB = new MyToken('Token B', 'TKB');
        user1 = vm.addr(1);
        rate = 5;
        swap = new TokenSwap(address(tokenA), address(tokenB), rate);
    }

    //Deal tokens to the Sale Contract
    modifier dealTokens(uint amtASwap, uint amtBSwap, uint amtAUser, uint amtBUser){
        (IERC20 A, IERC20 B, ) = swap.pair();
        deal(address(A), address(swap), amtASwap * 1e18);
        deal(address(B), address(swap), amtBSwap * 1e18);
        deal(address(A), address(user1), amtAUser * 1e18);
        deal(address(B), address(user1), amtBUser * 1e18);
        _;
    }

    /***********************************************************************************************/
    /**Users can swap Token A for Token B and vice versa.**/
    /**
    Swap A -> B:
        test with valid amounts:
            Amount to be swapped is not 0;
            Amount of  A wishing to be swapped is <= msg.sender's balance of A
            Amount of A is <= contract's balance of B / exchange rate
    **Proper checks to make sure exchange rate is adhered to
     */
    function test_fuzz_swapAtoB_valid_amounts(uint amtA) public dealTokens(0, 1000, 1000, 0){
        (IERC20 A, IERC20 B, uint exchangeRate) = swap.pair();
        uint userADealt = A.balanceOf(user1);
        uint swapBDealt = B.balanceOf(address(swap));
        vm.startPrank(address(user1));
        A.approve(address(swap), amtA);
        vm.assume(0 < amtA && amtA <= B.balanceOf(address(swap)) / exchangeRate 
                    && amtA <= userADealt);
        swap.swapAtoB(amtA);
        vm.stopPrank();
        assertEq(amtA * exchangeRate, B.balanceOf(user1));
        assertEq(userADealt - amtA, A.balanceOf(user1));
        assertEq(swapBDealt - amtA * exchangeRate, B.balanceOf(address(swap)));
    }

    /**
    Test fail if trying to swap and get token B that exceed's contract's balance of B
    */
    function testFail_fuzz_swapAtoB_swap_insufficient_output(uint amtA) public dealTokens(0, 100, 100, 0){
        (IERC20 A, , uint exchangeRate) = swap.pair();
        vm.startPrank(address(user1));
        A.approve(address(swap), amtA);
        vm.assume(0 < amtA && amtA > tokenB.balanceOf(address(swap)) / exchangeRate 
                    && amtA<= tokenA.balanceOf(user1));
        swap.swapAtoB(amtA);
        vm.stopPrank();
    }
    /**
    Test fail if msg.sender trying to swap more than msg.sender's balance of A
    */
    function testFail_fuzz_swapAtoB_swap_insufficient_input(uint amtA) public dealTokens(0, 100, 100, 0){
        (IERC20 A, , ) = swap.pair();
        vm.startPrank(address(user1));
        A.approve(address(swap), amtA);
        vm.assume(0 < amtA && amtA > tokenA.balanceOf(user1));
        swap.swapAtoB(amtA);
        vm.stopPrank();
    }

    /**
    Swap B -> A:
        test with valid amounts:
            Amount to be swapped is not 0;
            Amount of  B wishing to be swapped is <= msg.sender's balance of B
            Amount of B is leq to contract's balance of A * exchange rate
     */
    function test_fuzz_swapBtoA_valid_amounts(uint amtB) public dealTokens(1000, 0, 0, 1000){
        (IERC20 A, IERC20 B, uint exchangeRate) = swap.pair();
        uint userBDealt = B.balanceOf(user1);
        uint swapADealt = A.balanceOf(address(swap));
        vm.startPrank(address(user1));
        B.approve(address(swap), amtB);
        vm.assume(0 < amtB && amtB <= A.balanceOf(address(swap)) * exchangeRate 
                    && amtB <= B.balanceOf(user1));
        swap.swapBtoA(amtB);
        vm.stopPrank();
        assertEq(amtB / exchangeRate, A.balanceOf(user1));
        assertEq(userBDealt - amtB, B.balanceOf(user1));
        assertEq(swapADealt - amtB / exchangeRate, A.balanceOf(address(swap)));
    }
    /**
    Test fail if trying to swap B -> A that exceed's contract's balance of A
    */
    function testFail_fuzz_swapBtoA_swap_insufficient_output(uint amtB) public dealTokens(100, 0, 0, 100){
        (IERC20 A, IERC20 B, uint exchangeRate) = swap.pair();
        vm.startPrank(address(user1));
        A.approve(address(swap), amtB);
        vm.assume(0 < amtB && amtB > A.balanceOf(address(swap)) / exchangeRate 
                    && amtB <= B.balanceOf(user1));
        swap.swapAtoB(amtB);
        vm.stopPrank();
    }
    /**
    Test fail if msg.sender trying to swap more than msg.sender's balance of B
    */
    function testFail_fuzz_swapBtoA_swap_insufficient_input(uint amtB) public dealTokens(0, 100, 100, 0){
        (IERC20 A, , ) = swap.pair();
        vm.startPrank(address(user1));
        A.approve(address(swap), amtB);
        vm.assume(0 < amtB && amtB > A.balanceOf(user1));
        swap.swapAtoB(amtB);
        vm.stopPrank();
    }

}