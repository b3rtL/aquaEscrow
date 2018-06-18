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

  modifier isReceiver(uint _id){
    assert(transactions[_id].receiver == msg.sender);
    _;
  }

  modifier isSender(uint _id){
    assert(transactions[_id].sender == msg.sender);
    _;
  }

  modifier isNotComplete(uint _id){
    assert(!transactions[_id].complete);
    _;
  }

  event TxCreated(string indexed _id);
  event TxAccepted(bool indexed _accepted);
  event TxFinalized(bool indexed _receiverCanWithdraw);
  event TxCompleted(bool indexed _complete);

  constructor() public{
    txid = 0;
    owner = msg.sender;
  }

  function makeTransaction(address _receiver, uint _deadline, uint _collateral) public payable {
    require(msg.value != 0);

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

    txid++;
  }

  function acceptTransaction(uint _id) public payable isReceiver(_id) isNotComplete(_id) {
    require(msg.value == transactions[_id].collateral);
    assert(!transactions[_id].accepted);

    transactions[_id].accepted = true;
    transactions[_id].senderCanWithdraw = false;
    transactions[_id].deadline = now + (transactions[_id].deadline * 1 days);
    emit TxAccepted(transactions[_id].accepted);
  }

  function receiverWithdrawal(uint _id) public isReceiver(_id) isNotComplete(_id) {
    require(transactions[_id].receiverCanWithdraw ||
    ((now > transactions[_id].deadline)));
    assert(transactions[_id].accepted);

    uint collateral = transactions[_id].collateral;
    uint fee = transactions[_id].amount / 500;
    uint amount = transactions[_id].amount - fee;
    transactions[_id].complete = true;

    msg.sender.transfer(amount);
    owner.transfer(fee);
    transactions[_id].receiver.transfer(collateral);
    emit TxCompleted(transactions[_id].complete);
  }

  function senderWithdrawal(uint _id) public isSender(_id) isNotComplete(_id) {
    assert(transactions[_id].senderCanWithdraw);

    uint amount = transactions[_id].amount;
    transactions[_id].complete = true;

    if (transactions[_id].accepted) {
      uint collateral = transactions[_id].collateral;
      transactions[_id].receiver.transfer(collateral);
    }

    msg.sender.transfer(amount);
    }

  function finalizeTransaction(uint _id) public isSender(_id) isNotComplete(_id) {
    assert(!transactions[_id].receiverCanWithdraw);

    transactions[_id].receiverCanWithdraw = true;
    transactions[_id].senderCanWithdraw = false;
    emit TxFinalized(transactions[_id].receiverCanWithdraw);
  }

  function refundTransaction(uint _id) public isReceiver(_id) isNotComplete(_id) {
    assert(transactions[_id].accepted);

    transactions[_id].receiverCanWithdraw = false;
    transactions[_id].senderCanWithdraw = true;
  }

  function disputeTransaction(uint _id, uint addedTime) public isSender(_id) isNotComplete(_id) {
    require(now <= transactions[_id].deadline);
    assert(!transactions[_id].receiverCanWithdraw);

    transactions[_id].deadline += (addedTime * 1 days);
  }

  function liquidateExcess() public isOwner {
    owner.transfer(address(this).balance);
  }

  function getBalance() public view isOwner returns (uint) {
    return address(this).balance;
  }

  function kill() public isOwner {
    owner.transfer(address(this).balance);
    selfdestruct(owner);
  }

}
