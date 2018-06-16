pragma solidity ^0.4.2;

contract Escrow {

  struct transaction {
    uint amount;
    uint collateral;
    address sender;
    address receiver;
    uint id;
    uint deadline;
    bool accepted;
    bool senderCanWithdraw;
    bool receiverCanWithdraw;
    bool complete;
  }

  transaction[] public transactions;
  uint numTransactions = 0;

  address owner;

  modifier isOwner(){
    require(msg.sender == owner);
    _;
  }

  modifier isReceiver(uint id){
    require(transactions[id].receiver == msg.sender);
    _;
  }

  modifier isSender(uint id){
    require(transactions[id].sender == msg.sender);
    _;
  }

  modifier isNotComplete(uint id){
    require(!transactions[id].complete);
    _;
  }

  constructor() public{
    owner = msg.sender;
  }

  function makeTransaction(address receiver, uint deadline, uint collateral) public payable {
    require(msg.value != 0);

    transactions.push(transaction({
      amount: msg.value,
      collateral: collateral,
      sender: msg.sender,
      receiver: receiver,
      id: numTransactions,
      deadline: deadline,
      accepted: false,
      senderCanWithdraw: true,
      receiverCanWithdraw: false,
      complete: false
      }));

    numTransactions++;
  }

  function acceptTransaction(uint id) public payable isReceiver(id) isNotComplete(id) {
    require(!transactions[id].accepted && msg.value == transactions[id].collateral);

    transactions[id].accepted = true;
    transactions[id].senderCanWithdraw = false;
    transactions[id].deadline = now + (transactions[id].deadline * 1 days);
  }

  function receiverWithdrawal(uint id) public isReceiver(id) isNotComplete(id) {
    require(transactions[id].receiverCanWithdraw ||
    ((now > transactions[id].deadline) && (transactions[id].accepted)));

    uint collateral = transactions[id].collateral;
    uint fee = transactions[id].amount / 500;
    uint amount = transactions[id].amount - fee;
    transactions[id].complete = true;

    msg.sender.transfer(amount);
    owner.transfer(fee);
    transactions[id].receiver.transfer(collateral);
  }

  function senderWithdrawal(uint id) public isSender(id) isNotComplete(id) {
    require(transactions[id].senderCanWithdraw);

    uint amount = transactions[id].amount;
    transactions[id].complete = true;

    if (transactions[id].accepted) {
      uint collateral = transactions[id].collateral;
      transactions[id].receiver.transfer(collateral);
    }

    msg.sender.transfer(amount);
    }

  function finalizeTransaction(uint id) public isSender(id) isNotComplete(id) {
    require(!transactions[id].receiverCanWithdraw);

    transactions[id].receiverCanWithdraw = true;
    transactions[id].senderCanWithdraw = false;
  }

  function refundTransaction(uint id) public isReceiver(id) isNotComplete(id) {
    require(transactions[id].accepted);

    transactions[id].receiverCanWithdraw = false;
    transactions[id].senderCanWithdraw = true;
  }

  function disputeTransaction(uint id, uint addedTime) public isSender(id) isNotComplete(id) {
    require(now <= transactions[id].deadline && !transactions[id].receiverCanWithdraw);

    transactions[id].deadline += (addedTime * 1 days);
  }

  function liquidateExcess() public isOwner {
    owner.transfer(address(this).balance);
  }

  function getBalance() public view isOwner returns (uint) {
    return address(this).balance;
  }

}
