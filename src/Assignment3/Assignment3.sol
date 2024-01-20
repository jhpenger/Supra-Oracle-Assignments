pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenSwap is Ownable{
    struct SwapPair{
        IERC20 tokenA;
        IERC20 tokenB;
        uint exchangeRate;
    }
    SwapPair public pair;

    constructor(address _tokenA, address _tokenB, uint _exchangeRate) Ownable(msg.sender){
        pair = SwapPair(IERC20(_tokenA), IERC20(_tokenB), _exchangeRate);
    }

    event SwapAB(address indexed buyer, uint amtA, uint amtB);
    event SwapBA(address indexed buyer, uint amtB, uint amtA);

    modifier checkAtoB(uint amtA){
        require (amtA > 0, "Please enter valid swap amount");
        require(pair.tokenA.balanceOf(msg.sender) >= amtA,
                    "You don't have enough TokenA");
        require(pair.tokenB.balanceOf(address(this)) >= amtA * pair.exchangeRate,
                    "Swap doesn't have enough TokenB");
        _;
    }

    modifier checkBtoA(uint amtB){
        require (amtB >0, "Please enter valid swap amount");
        require(pair.tokenB.balanceOf(msg.sender) >= amtB,
                    "You don't have enough TokenB");
        require(pair.tokenA.balanceOf(address(this)) >= amtB / pair.exchangeRate,
                    "Swap doesn't have enough TokenA");
        _;
    }
    

    function swapAtoB(uint amtA) external checkAtoB(amtA){
        pair.tokenA.transferFrom(msg.sender, address(this), amtA);
        pair.tokenB.transfer(msg.sender, amtA * pair.exchangeRate);
        emit SwapAB(msg.sender, amtA, amtA * pair.exchangeRate);
    }

    function swapBtoA(uint amtB) external checkBtoA(amtB){
        pair.tokenB.transferFrom(msg.sender, address(this), amtB);
        pair.tokenA.transfer(msg.sender, amtB / pair.exchangeRate);
        emit SwapBA(msg.sender, amtB, amtB / pair.exchangeRate);
    }

    function withdrawA() external onlyOwner{
        pair.tokenA.transfer(owner(), pair.tokenA.balanceOf(address(this)));
    }
    function withdrawB() external onlyOwner {
        pair.tokenB.transfer(owner(), pair.tokenB.balanceOf(address(this)));
    }

}