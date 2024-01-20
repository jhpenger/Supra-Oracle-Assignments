pragma solidity >=0.7.0 <0.9.0;

// A wallet with multiple owners, each having their own private key.
// A specified number of owners (threshold) is required to approve and execute a transaction.
// Owners can submit, approve, and cancel transactions.

contract MultiSig{

    struct Owner{
        bool isOwner;
        uint[] proposals;
    }
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        address proposer;
        uint numVotes;
        bool cancelled;
    }

    address[] public ownersList;
    mapping(address => Owner) public owners;
    mapping(uint => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public isApproved;
    uint256 public numRequired;
    uint256 public txCount;

    event Vote(address indexed owner, uint indexed txId, bool approved);
    event Execution(uint indexed txId);
    event Cancellation(uint indexed txId, address to, uint value, bytes data, uint numVotes);

    modifier onlyOwner(){
        require(owners[msg.sender].isOwner, "Not an owner");
        _;
    }
    modifier txExists(uint _id){
        require(_id <txCount, "Transaction dne");
        _;
    }
    modifier notApproved(uint _id){
        require(!isApproved[_id][msg.sender], "You've already approved the proposal");
        _;
    }
    modifier notExecuted(uint _id){
        require(!transactions[_id].executed, "Transaction already executed");
        _;
    }
    modifier canExecute(uint _id){
        require(transactions[_id].numVotes >= numRequired, "Threshhold not met");
        _;
    }
    modifier isProposer(uint _id){
        require(msg.sender == transactions[_id].proposer, "You're not the proposer of this transaction");
        _;
    }
    modifier notCancelled(uint _id){
        require(!transactions[_id].cancelled, "Transaction has been cancelled by proposer");
        _;
    }

    constructor(address[] memory _ownersList, uint _numRequired){
        require(_ownersList.length > 0 && _numRequired > 0 && _numRequired <= _ownersList.length, "no owners given or bad num requirements given");
        ownersList = _ownersList;
        numRequired = _numRequired;
        for (uint i = 0; i < ownersList.length; i++){
            owners[ownersList[i]].isOwner = true;
        }
    }

    function submitTx(address _to, uint _value, bytes memory _data) external onlyOwner returns(uint){
        uint txId = txCount;
        transactions[txId] = Transaction(_to, _value, _data, false, msg.sender, 0, false);
        txCount++;
        owners[msg.sender].proposals.push(txId);
        approveTx(txId);
        return(txId);

    }

    function approveTx(uint _txId) public onlyOwner txExists(_txId) notExecuted(_txId) notApproved(_txId) notCancelled(_txId)returns(uint){
        isApproved[_txId][msg.sender] = true;
        transactions[_txId].numVotes++;
        emit Vote(msg.sender, _txId, true);
        if (transactions[_txId].numVotes == numRequired){
            executeTx(_txId);
        }
        return(transactions[_txId].numVotes);
    }

    function executeTx(uint _txId) internal txExists(_txId) notExecuted(_txId) canExecute(_txId) notCancelled(_txId){
        Transaction storage transaction = transactions[_txId];
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");
        transaction.executed = true;
        emit Execution(_txId);
    }

    function cancelTx(uint _txId) public isProposer(_txId) txExists(_txId) notExecuted(_txId) notCancelled(_txId){
        Transaction memory transaction = transactions[_txId];
        // delete transactions[_txId];

        transactions[_txId].cancelled = true;
        emit Cancellation(_txId, transaction.to, transaction.value, transaction.data, transaction.numVotes);
    }



}