// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdFund {
    address public owner;
    uint public goal;
    uint public deadline;
    uint public totalRaised;
    bool public isCancelled = false;
    bool public isPaused = false;
    uint public minimumContribution;

    mapping(address => uint) public contributions;
    mapping(address => string[]) public contributorMessages;
    mapping(address => uint) public messageEditCount;
    mapping(address => string) public contributorRewards;
    mapping(address => bool) public hasVoted;
    mapping(address => string) public contributorBadge;
    mapping(address => string) public publicFeedback;

    uint public rewardThreshold;
    string public rewardDescription;
    uint public votesToCancel;
    uint public milestoneWithdrawn;
    uint public messageEditLimit = 3;

    address[] public contributors;

    // Events
    event ContributionReceived(address contributor, uint amount, string message);
    event CampaignPaused();
    event CampaignResumed();
    event CampaignCancelled();
    event FundsWithdrawn(uint amount);
    event RefundIssued(address contributor, uint amount);
    event VoteToCancel(address voter);

    constructor(uint _goal, uint _durationInDays, uint _minimumContribution) {
        require(_goal > 0 && _durationInDays > 0 && _minimumContribution > 0, "Invalid parameters");
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + (_durationInDays * 1 days);
        minimumContribution = _minimumContribution;
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

    modifier notPaused() {
        require(!isPaused, "Campaign is paused");
        _;
    }

    function contribute(string memory _message) public payable beforeDeadline notCancelled notPaused {
        require(msg.value >= minimumContribution, "Below minimum contribution");

        if (contributions[msg.sender] == 0) {
            contributors.push(msg.sender);
        }

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        contributorMessages[msg.sender].push(_message);
        _assignReward(msg.sender);
        _assignBadge(msg.sender);

        emit ContributionReceived(msg.sender, msg.value, _message);
    }

    function increaseContribution(string memory _message) public payable beforeDeadline notCancelled notPaused {
        require(msg.value >= minimumContribution, "Below minimum contribution");
        require(contributions[msg.sender] > 0, "Not yet a contributor");

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        contributorMessages[msg.sender].push(_message);
        _assignReward(msg.sender);
        _assignBadge(msg.sender);

        emit ContributionReceived(msg.sender, msg.value, _message);
    }

    function withdrawMilestoneFunds(uint percent) public onlyOwner afterDeadline notCancelled {
        require(totalRaised >= goal, "Goal not reached");
        require(percent > 0 && percent <= 100, "Invalid percent");
        uint withdrawAmount = (address(this).balance * percent) / 100;
        require(milestoneWithdrawn + withdrawAmount <= address(this).balance, "Over withdrawal");

        milestoneWithdrawn += withdrawAmount;
        payable(owner).transfer(withdrawAmount);
        emit FundsWithdrawn(withdrawAmount);
    }

    function getRefund() public {
        require(block.timestamp >= deadline || isCancelled, "Not eligible for refund");
        require(totalRaised < goal || isCancelled, "Goal met or not cancelled");

        uint amount = contributions[msg.sender];
        require(amount > 0, "Nothing to refund");

        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit RefundIssued(msg.sender, amount);
    }

    function voteToCancel() public notCancelled beforeDeadline {
        require(contributions[msg.sender] > 0, "Only contributors can vote");
        require(!hasVoted[msg.sender], "Already voted");

        hasVoted[msg.sender] = true;
        votesToCancel++;

        emit VoteToCancel(msg.sender);

        if (votesToCancel > contributors.length / 2) {
            isCancelled = true;
            emit CampaignCancelled();
        }
    }

    function updateContributorMessage(uint index, string memory newMessage) public {
        require(index < contributorMessages[msg.sender].length, "Invalid index");
        require(messageEditCount[msg.sender] < messageEditLimit, "Edit limit exceeded");

        contributorMessages[msg.sender][index] = newMessage;
        messageEditCount[msg.sender]++;
    }

    function pauseCampaign() public onlyOwner {
        isPaused = true;
        emit CampaignPaused();
    }

    function resumeCampaign() public onlyOwner {
        isPaused = false;
        emit CampaignResumed();
    }

    function updateGoal(uint _newGoal) public onlyOwner beforeDeadline notCancelled {
        require(_newGoal > totalRaised, "New goal must exceed current raised amount");
        goal = _newGoal;
    }

    function setRewardTier(uint _threshold, string memory _description) public onlyOwner {
        require(_threshold > minimumContribution, "Threshold too low");
        rewardThreshold = _threshold;
        rewardDescription = _description;
    }

    function _assignReward(address contributor) internal {
        if (contributions[contributor] >= rewardThreshold && bytes(rewardDescription).length > 0) {
            contributorRewards[contributor] = rewardDescription;
        }
    }

    function _assignBadge(address contributor) internal {
        uint amount = contributions[contributor];
        if (amount >= 1 ether) {
            contributorBadge[contributor] = "Gold";
        } else if (amount >= 0.5 ether) {
            contributorBadge[contributor] = "Silver";
        } else {
            contributorBadge[contributor] = "Bronze";
        }
    }

    function leavePublicFeedback(string memory feedback) public {
        require(contributions[msg.sender] > 0, "Only contributors can leave feedback");
        require(bytes(feedback).length > 0, "Feedback cannot be empty");

        publicFeedback[msg.sender] = feedback;
    }

    function getAllFeedback() public view returns (address[] memory, string[] memory) {
        uint count = contributors.length;
        string[] memory feedbacks = new string[](count);

        for (uint i = 0; i < count; i++) {
            feedbacks[i] = publicFeedback[contributors[i]];
        }

        return (contributors, feedbacks);
    }

    // ========== View Functions ==========

    function getAllContributors() public view returns (address[] memory) {
        return contributors;
    }

    function getTotalContributors() public view returns (uint) {
        return contributors.length;
    }

    function getContributionOf(address contributor) public view returns (uint) {
        return contributions[contributor];
    }

    function getMessagesOf(address contributor) public view returns (string[] memory) {
        return contributorMessages[contributor];
    }

    function getRewardFor(address contributor) public view returns (string memory) {
        return contributorRewards[contributor];
    }

    function getBadgeOf(address contributor) public view returns (string memory) {
        return contributorBadge[contributor];
    }

    function getTopContributor() public view returns (address, uint) {
        address top;
        uint highest = 0;
        for (uint i = 0; i < contributors.length; i++) {
            address addr = contributors[i];
            if (contributions[addr] > highest) {
                highest = contributions[addr];
                top = addr;
            }
        }
        return (top, highest);
    }

    function checkCampaignStatus() public view returns (string memory) {
        if (isCancelled) return "Cancelled";
        if (block.timestamp < deadline) return "Active";
        if (totalRaised >= goal) return "Successful";
        return "Failed";
    }
}
