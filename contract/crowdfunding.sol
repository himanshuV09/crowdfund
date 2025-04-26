// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdFund {
    address public owner;
    uint public goal;
    uint public deadline;
    uint public totalRaised;
    bool public isCancelled = false;

    mapping(address => uint) public contributions;
    address[] public contributors;

    constructor(uint _goal, uint _durationInDays) {
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + (_durationInDays * 1 days);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    modifier beforeDeadline() {
        require(block.timestamp < deadline, "Deadline has passed");
        _;
    }

    modifier afterDeadline() {
        require(block.timestamp >= deadline, "Deadline not reached");
        _;
    }

    modifier notCancelled() {
        require(!isCancelled, "Campaign has been cancelled");
        _;
    }

    function contribute() public payable beforeDeadline notCancelled {
        require(msg.value > 0, "Must send some ether");

        if (contributions[msg.sender] == 0) {
            contributors.push(msg.sender);
        }

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
    }

    function withdrawFunds() public onlyOwner afterDeadline {
        require(!isCancelled, "Campaign was cancelled");
        require(totalRaised >= goal, "Funding goal not met");
        payable(owner).transfer(address(this).balance);
    }

    function getRefund() public {
        require(block.timestamp >= deadline || isCancelled, "Not eligible for refund yet");
        require(totalRaised < goal || isCancelled, "Funding goal was met and campaign not cancelled");
        uint amount = contributions[msg.sender];
        require(amount > 0, "No contributions to refund");
        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function checkCampaignStatus() public view returns (string memory) {
        if (isCancelled) {
            return "Cancelled";
        } else if (block.timestamp < deadline) {
            return "Active";
        } else if (totalRaised >= goal) {
            return "Successful";
        } else {
            return "Failed";
        }
    }

    function getAllContributors() public view returns (address[] memory) {
        return contributors;
    }

    function getTotalContributors() public view returns (uint) {
        return contributors.length;
    }

    function extendDeadline(uint _extraDays) public onlyOwner beforeDeadline notCancelled {
        require(_extraDays > 0, "Extension must be greater than zero");
        deadline += _extraDays * 1 days;
    }

    function getContributionOf(address _contributor) public view returns (uint) {
        return contributions[_contributor];
    }

    function cancelCampaign() public onlyOwner beforeDeadline {
        isCancelled = true;
    }

    //Update the goal (only owner, before deadline, not cancelled)
    function updateGoal(uint _newGoal) public onlyOwner beforeDeadline notCancelled {
        require(_newGoal > 0, "Goal must be greater than zero");
        goal = _newGoal;
    }
}
