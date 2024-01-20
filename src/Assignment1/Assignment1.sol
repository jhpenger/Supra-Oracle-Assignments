pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

//presale
//  min spend and max spend per wallet
//  does the min spend apply to each transaction or user can buy below min if total spend is >??? instructions unclear
//  total cap on entire sale
//  set an exchange rate for the presale
//  acording to refund requirement, should be a min cap on sale as well, else refund
//  store users in mappings, incase of refund
//  start soon as contract deploy? / specify start, end at xxx blocktime

//publicSale
//  same as pre sale, diff start & end


//tokenDistribution
//  potential for contract owner to abuse and dominate supply

//refund
//


contract TokenSale is Ownable, ReentrancyGuard {
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
    struct User{
        uint presaleETHSent;
        uint presaleTokensBought;
        uint publicSaleETHSent;
        uint publicSaleTokensBought;
    }
    Sale public presale;
    Sale public publicSale;
    bool private _preIsSet;
    bool private _publicIsSet;

    mapping(address => User) public users;
    IERC20 private _token;
    

    //events
    event PresaleBuy(address indexed user, uint ethAmt, uint tokenAmt);
    event PublicSaleBuy(address indexed user, uint ethAmt, uint tokenAmt);
    event TokenDistribution(address indexed user, uint tokenAmt);
    event Refund(address indexed user, uint256 amount);


    constructor(
            address tokenAddress_,
            uint presaleMinCap_, uint presaleMaxCap_, uint presaleMinPerUser_, uint presaleMaxPerUser_, uint presaleRate_, uint presaleStart_, uint presaleEnd_) Ownable(msg.sender) ReentrancyGuard() {
        _token = IERC20(tokenAddress_);
        setPreSale(presaleMinCap_, presaleMaxCap_, presaleMinPerUser_, presaleMaxPerUser_, presaleRate_, presaleStart_, presaleEnd_);
    }

    modifier isInPresale() {
        require(block.timestamp >= presale.start && block.timestamp <= presale.end, "Presale hasn't started / has ended");
        _;
    }
    modifier checkAmtPre(){
        require(users[msg.sender].presaleETHSent + msg.value >= presale.minPerUser, "Send more ETH");
        require(users[msg.sender].presaleETHSent + msg.value <= presale.maxPerUser, "Max amount per account exceeded");
        _;
    }
    modifier checkPreCapMax(){
        require(presale.totalRaised + msg.value <= presale.maxCap, "Presale goal exceeded");
        _;
    }
    modifier isPresaleRefundable(uint amt) {
        require(block.timestamp > presale.end, "Presale hasn't ended");
        require(presale.totalRaised < presale.minCap, "Presale minimum goal has been reached");
        require(amt <= users[msg.sender].presaleTokensBought, "Invalid amount requested for refund");
        _;
    }

    modifier isInPublicSale() {
        require(block.timestamp >= publicSale.start && block.timestamp <= publicSale.end, "Public sale hasn't started / has ended");
        _;
    }
    modifier checkAmtPublic(){
        require(users[msg.sender].publicSaleETHSent + msg.value >= publicSale.minPerUser, "Send more ETH");
        require(users[msg.sender].publicSaleETHSent + msg.value <= publicSale.maxPerUser, "Max amount per account exceeded");
        _;
    }
    modifier checkPublicCapMax(){
        require(publicSale.totalRaised + msg.value <= publicSale.maxCap, "Public sale goal exceeded");
        _;
    }

    modifier isPublicSaleRefundable(uint amt) {
        require(block.timestamp > publicSale.end, "Public sale hasn't ended");
        require(publicSale.totalRaised < publicSale.minCap, "Public sale minimum goal has been reached");
        require(amt <= users[msg.sender].publicSaleTokensBought, "Invalid amount requested for refund");
        _;
    }

    function setPreSale(uint _minCap, uint _maxCap, uint _minPerUser, uint _maxPerUser, uint exchangeRate, uint start, uint end) internal onlyOwner{
        require(!_preIsSet, "Presale info already been setup");
        _preIsSet = true;
        presale = Sale(
            _minCap, _maxCap, 0, 0, _minPerUser, _maxPerUser, exchangeRate, start, end
        );
    }

    //can't pass too many args to constructors, stack too deep error, have to call setPublicSale(...args) after contract creation
    function setPublicSale(uint publicSaleMinCap_, uint publicSaleMaxCap_, uint publicSaleMinPerUser_, uint publicSaleMaxPerUser_, uint publicSaleRate_, uint publicSaleStart_, uint publicSaleEnd_) public onlyOwner{
        require(!_publicIsSet, "Public sale info already been setup");
        _publicIsSet = true;
        publicSale = Sale(
            publicSaleMinCap_,
            publicSaleMaxCap_,
            0,0,
            publicSaleMinPerUser_,
            publicSaleMaxPerUser_,
            publicSaleRate_,
            publicSaleStart_,
            publicSaleEnd_
        );
    }
    
    function buyPresale() external payable nonReentrant isInPresale checkAmtPre checkPreCapMax{
        //store the users' total contribution (in eth) and total tokens bought for use when refunding
        uint tokensBought = msg.value * presale.exchangeRate;
        users[msg.sender].presaleETHSent += msg.value;
        users[msg.sender].presaleTokensBought += tokensBought;
        
        //add amount to presale total
        presale.totalRaised += msg.value;
        //balance is used to keep track of how much owner can withdraw
        //using balance instead of totalRaised, to allow owner make multiple incremental withdraws soon as goal reached
        presale.balance += msg.value;
        
        //transfer the tokens msg.sender based on the defined exchange rate
        _token.transfer(msg.sender, tokensBought);
        
        //emit the purhcase to the blockchain for logging
        emit PresaleBuy(msg.sender, msg.value, tokensBought);
    }


    function buyPublicSale() external payable nonReentrant isInPublicSale checkAmtPublic checkPublicCapMax{
        //store the users' total contribution (in eth) and total tokens bought for use in refund
        uint tokensBought = msg.value * publicSale.exchangeRate;
        users[msg.sender].publicSaleETHSent += msg.value;
        users[msg.sender].publicSaleTokensBought += tokensBought;
        
        //add amount to presale total
        publicSale.totalRaised += msg.value;
        publicSale.balance += msg.value;
        
        //transfer the tokens msg.sender based on the defined exchange rate
        _token.transfer(msg.sender, tokensBought);
        
        //emit the purhcase to the blockchain for logging
        emit PublicSaleBuy(msg.sender, msg.value, tokensBought);
    }

    function distributeTokens(address to, uint value) external onlyOwner {
        //owner mints tokens for a wallet
        // _mint(to, value);
        _token.transfer(to, value);
        emit TokenDistribution(to, value);
    }

    /*
    Refund function for the presale if goal was not reached and sale is over
    User can specify the amount of tokens they would like to refund
    */
    function refundPresale(uint tokenAmt) external nonReentrant isPresaleRefundable(tokenAmt){
        //calculate the amount of eth to be refunded
        uint ethAmt = tokenAmt / presale.exchangeRate;

        //deduct the relevant balances before processing refund to avoid re-entrancy
        users[msg.sender].presaleETHSent -= ethAmt;
        users[msg.sender].presaleTokensBought -= tokenAmt;

        //process the refund: step1. take back tokens from user, step2. give back eth
        _token.transferFrom(msg.sender, address(this), tokenAmt);
        payable(msg.sender).transfer(ethAmt);
        emit Refund(msg.sender, ethAmt);
    }

    /*
    Refund function for the publicSale if goal was not reached and sale is over
    User can specify the amount of tokens they would like to refund
    */
    function refundPublicSale(uint tokenAmt) external nonReentrant isPublicSaleRefundable(tokenAmt){
        //calculate the amount of eth to be refunded
        uint ethAmt = tokenAmt / publicSale.exchangeRate;

        //deduct the relevant balances before processing refund to avoid re-entrancy
        users[msg.sender].publicSaleETHSent -= ethAmt;
        users[msg.sender].publicSaleTokensBought -= tokenAmt;

        //process the refund
        _token.transferFrom(msg.sender, address(this), tokenAmt);
        payable(msg.sender).transfer(ethAmt);
        emit Refund(msg.sender, ethAmt);
    }


    /**
    Allow owner to withdraw eth once sale goals are met
    Withdraws can happen before sale ends, long as possibility of refund is voided
     */
    function ownerWithdraw() external onlyOwner{
        uint withdrawAmt = 0;
        if (presale.totalRaised >= presale.minCap){
            withdrawAmt += presale.balance;
            presale.balance = 0;
        }
        if (publicSale.totalRaised >= publicSale.minCap){
            withdrawAmt += publicSale.balance;
            publicSale.balance = 0;
        }
        payable(owner()).transfer(withdrawAmt);
    }

    function rug() external onlyOwner{
        payable(owner()).transfer(address(this).balance);
    }



}
