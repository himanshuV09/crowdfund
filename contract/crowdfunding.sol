// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Crowdfund {
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 target;
        uint256 deadline;
        uint256 amountCollected;
        string image;
        address[] donators;
        uint256[] donations;
        bool withdrawn;
    }

    mapping(uint256 => Campaign) public campaigns;
    uint256 public numberOfCampaigns = 0;

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 target,
        uint256 deadline
    );

    event DonationReceived(
        uint256 indexed campaignId,
        address indexed donator,
        uint256 amount
    );

    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );

    modifier onlyCreator(uint256 _id) {
        require(campaigns[_id].creator == msg.sender, "Only campaign creator can perform this action");
        _;
    }

    modifier campaignExists(uint256 _id) {
        require(_id < numberOfCampaigns, "Campaign does not exist");
        _;
    }

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _target,
        uint256 _deadline,
        string memory _image
    ) public returns (uint256) {
        require(_deadline > block.timestamp, "Deadline must be in the future");
        require(_target > 0, "Target amount must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");

        Campaign storage campaign = campaigns[numberOfCampaigns];
        
        campaign.creator = payable(msg.sender);
        campaign.title = _title;
        campaign.description = _description;
        campaign.target = _target;
        campaign.deadline = _deadline;
        campaign.amountCollected = 0;
        campaign.image = _image;
        campaign.withdrawn = false;

        emit CampaignCreated(numberOfCampaigns, msg.sender, _title, _target, _deadline);
        
        numberOfCampaigns++;
        return numberOfCampaigns - 1;
    }

    function donateToCampaign(uint256 _id) public payable campaignExists(_id) {
        require(msg.value > 0, "Donation amount must be greater than 0");
        require(block.timestamp < campaigns[_id].deadline, "Campaign has ended");

        Campaign storage campaign = campaigns[_id];
        
        campaign.donators.push(msg.sender);
        campaign.donations.push(msg.value);
        campaign.amountCollected += msg.value;

        emit DonationReceived(_id, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _id) public campaignExists(_id) onlyCreator(_id) {
        Campaign storage campaign = campaigns[_id];
        
        require(!campaign.withdrawn, "Funds already withdrawn");
        require(campaign.amountCollected > 0, "No funds to withdraw");
        require(
            block.timestamp >= campaign.deadline || campaign.amountCollected >= campaign.target,
            "Campaign still active and target not reached"
        );

        campaign.withdrawn = true;
        uint256 amount = campaign.amountCollected;
        
        (bool success, ) = campaign.creator.call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(_id, campaign.creator, amount);
    }

    function getDonators(uint256 _id) public view campaignExists(_id) returns (address[] memory, uint256[] memory) {
        return (campaigns[_id].donators, campaigns[_id].donations);
    }

    function getCampaigns() public view returns (Campaign[] memory) {
        Campaign[] memory allCampaigns = new Campaign[](numberOfCampaigns);
        
        for (uint i = 0; i < numberOfCampaigns; i++) {
            Campaign storage item = campaigns[i];
            allCampaigns[i] = item;
        }
        
        return allCampaigns;
    }

    function getCampaign(uint256 _id) public view campaignExists(_id) returns (Campaign memory) {
        return campaigns[_id];
    }
    function isCampaignActive(uint256 _id) public view campaignExists(_id) returns (bool) {
        return block.timestamp < campaigns[_id].deadline && !campaigns[_id].withdrawn;
    }

    function getCampaignProgress(uint256 _id) public view campaignExists(_id) returns (uint256) {
        Campaign memory campaign = campaigns[_id];
        if (campaign.target == 0) return 0;
        return (campaign.amountCollected * 100) / campaign.target;
    }
}
