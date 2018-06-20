pragma solidity ^0.4.2;

contract Escrow {

  struct Transaction {
    uint amount;
    uint collateral;
    address sender;
    address receiver;
    uint deadline;
    bool accepted;
    bool senderCanWithdraw;
    bool receiverCanWithdraw;
    bool complete;
  }

  mapping(uint => Transaction) public transactions;
  uint public txid;

  address owner;

  modifier isOwner(){
    assert(msg.sender == owner);
    _;
  }

  modifier isReceiver(uint _txid){
    assert(transactions[_txid].receiver == msg.sender);
    _;
  }

  modifier isSender(uint _txid){
    assert(transactions[_txid].sender == msg.sender);
    _;
  }

  modifier isNotComplete(uint _txid){
    assert(!transactions[_txid].complete);
    _;
  }

  event TxCreated(string indexed _txid);
  event TxAccepted(bool indexed _accepted);
  event TxFinalized(bool indexed _receiverCanWithdraw);
  event TxCompleted(bool indexed _complete);

  constructor() public{
    txid = 0;
    owner = msg.sender;
  }

  function makeTransaction(address _receiver, uint _deadline, uint _collateral) public payable {
    require(msg.value != 0);
    txid++;

    transactions[txid] = Transaction({
      amount: msg.value,
      collateral: _collateral,
      sender: msg.sender,
      receiver: _receiver,
      deadline: _deadline,
      accepted: false,
      senderCanWithdraw: true,
      receiverCanWithdraw: false,
      complete: false
      });
  }

  function acceptTx(uint _txid) public payable isReceiver(_txid) isNotComplete(_txid) {
    require(msg.value == transactions[_txid].collateral);
    assert(!transactions[_txid].accepted);

    transactions[_txid].accepted = true;
    transactions[_txid].senderCanWithdraw = false;
    transactions[_txid].deadline = now + (transactions[_txid].deadline * 1 days);
    emit TxAccepted(transactions[_txid].accepted);
  }

  function receiverWithdrawal(uint _txid) public isReceiver(_txid) isNotComplete(_txid) {
    require(transactions[_txid].receiverCanWithdraw ||
    ((now > transactions[_txid].deadline)));
    assert(transactions[_txid].accepted);

    uint collateral = transactions[_txid].collateral;
    uint fee = transactions[_txid].amount / 500;
    uint amount = transactions[_txid].amount - fee;
    transactions[_txid].complete = true;

    msg.sender.transfer(amount);
    owner.transfer(fee);
    transactions[_txid].receiver.transfer(collateral);
    emit TxCompleted(transactions[_txid].complete);
  }

  function senderWithdrawal(uint _txid) public isSender(_txid) isNotComplete(_txid) {
    assert(transactions[_txid].senderCanWithdraw);

    uint amount = transactions[_txid].amount;
    transactions[_txid].complete = true;

    if (transactions[_txid].accepted) {
      uint collateral = transactions[_txid].collateral;
      transactions[_txid].receiver.transfer(collateral);
    }

    msg.sender.transfer(amount);
    }

  function finalizeTx(uint _txid) public isSender(_txid) isNotComplete(_txid) {
    assert(!transactions[_txid].receiverCanWithdraw);

    transactions[_txid].receiverCanWithdraw = true;
    transactions[_txid].senderCanWithdraw = false;
    emit TxFinalized(transactions[_txid].receiverCanWithdraw);
  }

  function refundTx(uint _txid) public isReceiver(_txid) isNotComplete(_txid) {
    assert(transactions[_txid].accepted);

    transactions[_txid].receiverCanWithdraw = false;
    transactions[_txid].senderCanWithdraw = true;
  }

  function disputeTx(uint _txid, uint addedTime) public isSender(_txid) isNotComplete(_txid) {
    require(now <= transactions[_txid].deadline);
    assert(!transactions[_txid].receiverCanWithdraw);

    transactions[_txid].deadline += (addedTime * 1 days);
  }

  function liquidateExcess() public isOwner {
    owner.transfer(address(this).balance);
  }

  function getBal() public view isOwner returns (uint) {
    return address(this).balance;
  }

  function kill() public isOwner {
    owner.transfer(address(this).balance);
    selfdestruct(owner);
  }

}
