// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IIDRXToken {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function decimals() external view returns (uint8);
}

interface ICommunityToken {
    function mint(address to, uint256 amount) external;

    function transfer(address to, uint256 amount) external returns (bool);

    function decimals() external view returns (uint8);
}

import "./CommunityERC20.sol";

contract DAOLaunchpad is Ownable {
    struct CommunityProposal {
        string title;
        string image;
        string github;
        string whitepaper;
        string ownerLink;
        string description;
        string motivasi;
        string rincian;
        string keuntungan;
        string tantangan;
        string dampakdanhasil;
        address proposer;
        uint256 requestedAmount;
        uint256 deadline;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 quorum;
        bool executed;
        bool approved;
        uint256 totalYesPower;
        uint256 totalNoPower;
    }

    // New struct for proposal creation parameters
    struct ProposalParams {
        string title;
        string image;
        string github;
        string whitepaper;
        string ownerLink;
        string description;
        string motivasi;
        string rincian;
        string keuntungan;
        string tantangan;
        string dampakdanhasil;
        uint256 requestedAmount;
        uint256 deadline;
        uint256 quorum;
    }

    struct SubProposal {
        string title;
        string description;
        address proposer;
        uint256 requestedAmount;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 totalYesPower;
        uint256 totalNoPower;
        bool approved;
        bool executed;
        uint256 deadline;
        uint256 quorum;
        mapping(address => bool) hasVoted;
        address[] voters;
    }

    struct CommunityTokenInfo {
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        address tokenAddress;
        address creator;
        uint256 createdAt;
        uint256 teamAllocation;
        uint256 communityAllocation;
        uint256 publicAllocation;
        bool distributed;
    }

    struct ProposalSummary {
        string title;
        string image;
        string github;
        string whitepaper;
        string ownerLink;
        string description;
        string motivasi;
        string rincian;
        string keuntungan;
        string tantangan;
        string dampakdanhasil;
        address proposer;
        uint256 requestedAmount;
        uint256 deadline;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 quorum;
        bool executed;
        bool approved;
        uint256 totalYesPower;
        uint256 totalNoPower;
        address tokenAddress;
        bool distributed;
    }

    struct VoterInfo {
        address voter;
        uint256 votingPower;
        bool support;
    }

    struct SubProposalSummary {
        string title;
        string description;
        address proposer;
        uint256 requestedAmount;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 totalYesPower;
        uint256 totalNoPower;
        bool approved;
        bool executed;
    }

    IIDRXToken public idrx;
    uint256 public constant MINIMUM_VOTING_POWER = 100 * 10 ** 2; // 100 IDRX (2 decimals)
    uint256 public constant MAXIMUM_VOTING_POWER = 10000 * 10 ** 2; // 10000 IDRX (2 decimals)
    uint256 public constant MINIMUM_PROPOSAL_DURATION = 1 days;
    uint256 public constant MAXIMUM_PROPOSAL_DURATION = 30 days;

    // Track locked tokens per user
    mapping(address => uint256) public lockedIDRX;

    CommunityProposal[] public communityProposals;
    mapping(uint256 => mapping(address => uint256)) public votingPower;
    mapping(uint256 => CommunityTokenInfo) public communityTokens;
    mapping(uint256 => SubProposal[]) public communitySubProposals;
    mapping(uint256 => address[]) public yesVoters;
    mapping(uint256 => address[]) public noVoters;

    // Events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer);
    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        bool vote,
        uint256 power
    );
    event CommunityTokenCreated(
        uint256 indexed proposalId,
        address tokenAddress
    );
    event TokenDistributed(uint256 proposalId, address voter, uint256 amount);
    event Locked(address indexed user, uint256 amount);
    event Unlocked(address indexed user, uint256 amount);

    // Events for subproposals
    event SubProposalCreated(
        uint256 indexed communityId,
        uint256 indexed subProposalId,
        address indexed proposer
    );
    event SubProposalVoted(
        uint256 indexed communityId,
        uint256 indexed subProposalId,
        address indexed voter,
        bool support,
        uint256 power
    );
    event SubProposalExecuted(
        uint256 indexed communityId,
        uint256 indexed subProposalId,
        bool approved
    );

    constructor(address _idrx) Ownable(msg.sender) {
        require(_idrx != address(0), "Invalid IDRX address");
        idrx = IIDRXToken(_idrx);
    }

    // Lock IDRX to get voting power
    function lockIDRX(uint256 amount) external {
        require(amount >= MINIMUM_VOTING_POWER, "Below minimum lock amount");
        require(amount <= MAXIMUM_VOTING_POWER, "Above maximum lock amount");
        require(
            idrx.transferFrom(msg.sender, address(this), amount),
            "IDRX transfer failed"
        );
        lockedIDRX[msg.sender] += amount;
        emit Locked(msg.sender, amount);
    }

    // Unlock IDRX after proposal is executed
    function unlockIDRX(uint256 amount) external {
        require(lockedIDRX[msg.sender] >= amount, "Insufficient locked");
        lockedIDRX[msg.sender] -= amount;
        require(idrx.transfer(msg.sender, amount), "Unlock transfer failed");
        emit Unlocked(msg.sender, amount);
    }

    // Create new community proposal
    function createCommunityProposal(ProposalParams calldata params) external {
        require(bytes(params.title).length > 0, "Title cannot be empty");
        require(
            params.deadline >= block.timestamp + MINIMUM_PROPOSAL_DURATION,
            "Deadline too soon"
        );
        require(
            params.deadline <= block.timestamp + MAXIMUM_PROPOSAL_DURATION,
            "Deadline too far"
        );
        require(params.quorum > 0, "Quorum must be positive");

        CommunityProposal storage newProposal = communityProposals.push();
        newProposal.title = params.title;
        newProposal.image = params.image;
        newProposal.github = params.github;
        newProposal.whitepaper = params.whitepaper;
        newProposal.ownerLink = params.ownerLink;
        newProposal.description = params.description;
        newProposal.motivasi = params.motivasi;
        newProposal.rincian = params.rincian;
        newProposal.keuntungan = params.keuntungan;
        newProposal.tantangan = params.tantangan;
        newProposal.dampakdanhasil = params.dampakdanhasil;
        newProposal.proposer = msg.sender;
        newProposal.requestedAmount = params.requestedAmount;
        newProposal.deadline = params.deadline;
        newProposal.quorum = params.quorum;

        emit ProposalCreated(communityProposals.length - 1, msg.sender);
    }

    // Vote on community proposal
    function vote(
        uint256 proposalId,
        bool support,
        uint256 power
    ) external validProposalId(proposalId) proposalNotExecuted(proposalId) {
        CommunityProposal storage proposal = communityProposals[proposalId];
        require(block.timestamp < proposal.deadline, "Voting period ended");
        require(votingPower[proposalId][msg.sender] == 0, "Already voted");
        require(power <= lockedIDRX[msg.sender], "Insufficient voting power");
        require(power >= MINIMUM_VOTING_POWER, "Below minimum voting power");

        votingPower[proposalId][msg.sender] = power;

        if (support) {
            proposal.yesVotes++;
            proposal.totalYesPower += power;
            yesVoters[proposalId].push(msg.sender);
        } else {
            proposal.noVotes++;
            proposal.totalNoPower += power;
            noVoters[proposalId].push(msg.sender);
        }

        emit Voted(proposalId, msg.sender, support, power);
    }

    // Execute proposal, create community token, and distribute allocations
    function executeProposal(
        uint256 proposalId,
        string memory name,
        string memory symbol
    ) external {
        CommunityProposal storage proposal = communityProposals[proposalId];
        require(!proposal.executed, "Already executed");
        require(block.timestamp > proposal.deadline, "Voting not ended");
        require(
            proposal.totalYesPower + proposal.totalNoPower >= proposal.quorum,
            "Quorum not reached"
        );

        proposal.executed = true;
        proposal.approved = proposal.totalYesPower > proposal.totalNoPower;

        if (proposal.approved) {
            address token = createCommunityToken(name, symbol, 2);
            uint256 total = 1_000_000_000; // 1B
            communityTokens[proposalId] = CommunityTokenInfo({
                name: name,
                symbol: symbol,
                decimals: 2,
                totalSupply: total,
                tokenAddress: token,
                creator: proposal.proposer,
                createdAt: block.timestamp,
                teamAllocation: (total * 5) / 100,
                communityAllocation: (total * 55) / 100,
                publicAllocation: (total * 45) / 100,
                distributed: false
            });

            ICommunityToken(token).mint(address(this), total);
            distributeCommunityTokens(proposalId);
            emit CommunityTokenCreated(proposalId, token);
        }
    }

    // Internal: create ERC20 token for community
    function createCommunityToken(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) internal returns (address) {
        CommunityERC20 token = new CommunityERC20(name, symbol, decimals_);
        return address(token);
    }

    // Distribute allocations (team, voters, public)
    function distributeCommunityTokens(uint256 proposalId) internal {
        CommunityTokenInfo storage tokenInfo = communityTokens[proposalId];
        require(!tokenInfo.distributed, "Already distributed");
        tokenInfo.distributed = true;

        uint256 totalCommunity = tokenInfo.communityAllocation;
        ICommunityToken token = ICommunityToken(tokenInfo.tokenAddress);

        uint256 totalPower = communityProposals[proposalId].totalYesPower +
            communityProposals[proposalId].totalNoPower;
        require(totalPower > 0, "No voters");

        // Distribute to all voters (yes & no) proportionally
        for (uint256 i = 0; i < yesVoters[proposalId].length; i++) {
            address voter = yesVoters[proposalId][i];
            uint256 power = votingPower[proposalId][voter];
            uint256 reward = (power * totalCommunity) / totalPower;
            token.transfer(voter, reward);
            emit TokenDistributed(proposalId, voter, reward);
        }

        for (uint256 i = 0; i < noVoters[proposalId].length; i++) {
            address voter = noVoters[proposalId][i];
            uint256 power = votingPower[proposalId][voter];
            uint256 reward = (power * totalCommunity) / totalPower;
            token.transfer(voter, reward);
            emit TokenDistributed(proposalId, voter, reward);
        }

        // Team allocation (dummy vesting: langsung ke creator)
        token.transfer(tokenInfo.creator, tokenInfo.teamAllocation);

        // Public allocation: tetap di contract, nanti bisa di-claim lewat fundraising/swap
        // token.transfer(address(this), tokenInfo.publicAllocation); // Sudah di sini
    }

    // Fundraising: user deposit IDRX, dapat community token dari public allocation (simple swap)
    function fundraising(uint256 proposalId, uint256 idrxAmount) external {
        CommunityTokenInfo storage tokenInfo = communityTokens[proposalId];
        require(tokenInfo.tokenAddress != address(0), "Token not created");
        require(tokenInfo.publicAllocation > 0, "No public allocation left");
        require(
            idrx.transferFrom(msg.sender, address(this), idrxAmount),
            "IDRX transfer failed"
        );

        // Simple swap: 1 IDRX = 1 Community Token (adjust as needed)
        uint256 amountToReceive = idrxAmount;
        require(
            tokenInfo.publicAllocation >= amountToReceive,
            "Insufficient public allocation"
        );

        tokenInfo.publicAllocation -= amountToReceive;
        ICommunityToken(tokenInfo.tokenAddress).transfer(
            msg.sender,
            amountToReceive
        );
    }

    // Community subproposals (Grants/Bounty/Governance)
    function createSubProposal(
        uint256 communityId,
        string memory title,
        string memory description,
        uint256 requestedAmount,
        uint256 deadline,
        uint256 quorum
    ) external {
        require(
            communityTokens[communityId].tokenAddress != address(0),
            "Community not exist"
        );
        require(bytes(title).length > 0, "Title cannot be empty");
        require(
            deadline >= block.timestamp + MINIMUM_PROPOSAL_DURATION,
            "Deadline too soon"
        );
        require(
            deadline <= block.timestamp + MAXIMUM_PROPOSAL_DURATION,
            "Deadline too far"
        );
        require(quorum > 0, "Quorum must be positive");

        SubProposal storage sub = communitySubProposals[communityId].push();
        sub.title = title;
        sub.description = description;
        sub.proposer = msg.sender;
        sub.requestedAmount = requestedAmount;
        sub.deadline = deadline;
        sub.quorum = quorum;

        emit SubProposalCreated(
            communityId,
            communitySubProposals[communityId].length - 1,
            msg.sender
        );
    }

    // Vote on subproposal
    function voteSubProposal(
        uint256 communityId,
        uint256 subProposalId,
        bool support,
        uint256 power
    ) external {
        require(
            communityId < communityProposals.length,
            "Invalid community ID"
        );
        require(
            subProposalId < communitySubProposals[communityId].length,
            "Invalid subproposal ID"
        );

        SubProposal storage sub = communitySubProposals[communityId][
            subProposalId
        ];
        require(block.timestamp < sub.deadline, "Voting period ended");
        require(!sub.hasVoted[msg.sender], "Already voted");
        require(power <= lockedIDRX[msg.sender], "Insufficient voting power");
        require(power >= MINIMUM_VOTING_POWER, "Below minimum voting power");

        sub.hasVoted[msg.sender] = true;
        sub.voters.push(msg.sender);

        if (support) {
            sub.yesVotes++;
            sub.totalYesPower += power;
        } else {
            sub.noVotes++;
            sub.totalNoPower += power;
        }

        emit SubProposalVoted(
            communityId,
            subProposalId,
            msg.sender,
            support,
            power
        );
    }

    // Execute subproposal
    function executeSubProposal(
        uint256 communityId,
        uint256 subProposalId
    ) external {
        require(
            communityId < communityProposals.length,
            "Invalid community ID"
        );
        require(
            subProposalId < communitySubProposals[communityId].length,
            "Invalid subproposal ID"
        );

        SubProposal storage sub = communitySubProposals[communityId][
            subProposalId
        ];
        require(!sub.executed, "Already executed");
        require(block.timestamp > sub.deadline, "Voting not ended");
        require(
            sub.totalYesPower + sub.totalNoPower >= sub.quorum,
            "Quorum not reached"
        );

        sub.executed = true;
        sub.approved = sub.totalYesPower > sub.totalNoPower;

        if (sub.approved) {
            // Transfer requested amount to proposer
            ICommunityToken token = ICommunityToken(
                communityTokens[communityId].tokenAddress
            );
            require(
                token.transfer(sub.proposer, sub.requestedAmount),
                "Transfer failed"
            );
        }

        emit SubProposalExecuted(communityId, subProposalId, sub.approved);
    }

    // Get subproposal voters
    function getSubProposalVoters(
        uint256 communityId,
        uint256 subProposalId
    ) external view returns (VoterInfo[] memory) {
        require(
            communityId < communityProposals.length,
            "Invalid community ID"
        );
        require(
            subProposalId < communitySubProposals[communityId].length,
            "Invalid subproposal ID"
        );

        SubProposal storage sub = communitySubProposals[communityId][
            subProposalId
        ];
        VoterInfo[] memory voters = new VoterInfo[](sub.voters.length);

        for (uint256 i = 0; i < sub.voters.length; i++) {
            address voter = sub.voters[i];
            bool support = sub.totalYesPower > sub.totalNoPower;
            voters[i] = VoterInfo({
                voter: voter,
                votingPower: support ? sub.totalYesPower : sub.totalNoPower,
                support: support
            });
        }

        return voters;
    }

    // Add more functions for managing subproposals, grants, bounty, etc.

    // Add emergency withdrawal function for owner
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");

        if (token == address(idrx)) {
            require(
                IIDRXToken(token).transfer(owner(), amount),
                "Transfer failed"
            );
        } else {
            require(
                ICommunityToken(token).transfer(owner(), amount),
                "Transfer failed"
            );
        }
    }

    // Get all proposals with summaries
    function getProposals() external view returns (ProposalSummary[] memory) {
        uint256 length = communityProposals.length;
        ProposalSummary[] memory summaries = new ProposalSummary[](length);

        for (uint256 i = 0; i < length; i++) {
            CommunityProposal storage p = communityProposals[i];
            CommunityTokenInfo storage t = communityTokens[i];
            summaries[i] = _createProposalSummary(p, t);
        }
        return summaries;
    }

    // Helper function to create a proposal summary
    function _createProposalSummary(
        CommunityProposal storage p,
        CommunityTokenInfo storage t
    ) internal view returns (ProposalSummary memory) {
        return
            ProposalSummary({
                title: p.title,
                image: p.image,
                github: p.github,
                whitepaper: p.whitepaper,
                ownerLink: p.ownerLink,
                description: p.description,
                motivasi: p.motivasi,
                rincian: p.rincian,
                keuntungan: p.keuntungan,
                tantangan: p.tantangan,
                dampakdanhasil: p.dampakdanhasil,
                proposer: p.proposer,
                requestedAmount: p.requestedAmount,
                deadline: p.deadline,
                yesVotes: p.yesVotes,
                noVotes: p.noVotes,
                quorum: p.quorum,
                executed: p.executed,
                approved: p.approved,
                totalYesPower: p.totalYesPower,
                totalNoPower: p.totalNoPower,
                tokenAddress: t.tokenAddress,
                distributed: t.distributed
            });
    }

    // Get detailed information about a specific proposal
    function getProposalDetails(
        uint256 proposalId
    ) external view returns (CommunityProposal memory) {
        require(proposalId < communityProposals.length, "Invalid proposal ID");
        return communityProposals[proposalId];
    }

    // Get token information for a proposal
    function getTokenInfo(
        uint256 proposalId
    )
        external
        view
        returns (
            string memory name,
            string memory symbol,
            uint8 decimals,
            uint256 totalSupply,
            address tokenAddress,
            address creator,
            uint256 createdAt,
            uint256 teamAllocation,
            uint256 communityAllocation,
            uint256 publicAllocation,
            bool distributed
        )
    {
        require(proposalId < communityProposals.length, "Invalid proposal ID");
        CommunityTokenInfo storage t = communityTokens[proposalId];

        return (
            t.name,
            t.symbol,
            t.decimals,
            t.totalSupply,
            t.tokenAddress,
            t.creator,
            t.createdAt,
            t.teamAllocation,
            t.communityAllocation,
            t.publicAllocation,
            t.distributed
        );
    }

    // Get all voters for a proposal
    function getVoters(
        uint256 proposalId
    ) external view returns (VoterInfo[] memory) {
        require(proposalId < communityProposals.length, "Invalid proposal ID");

        address[] memory yesVotersList = yesVoters[proposalId];
        address[] memory noVotersList = noVoters[proposalId];
        uint256 totalVoters = yesVotersList.length + noVotersList.length;

        VoterInfo[] memory voters = new VoterInfo[](totalVoters);
        uint256 currentIndex = 0;

        // Add yes voters
        for (uint256 i = 0; i < yesVotersList.length; i++) {
            address voter = yesVotersList[i];
            voters[currentIndex] = VoterInfo({
                voter: voter,
                votingPower: votingPower[proposalId][voter],
                support: true
            });
            currentIndex++;
        }

        // Add no voters
        for (uint256 i = 0; i < noVotersList.length; i++) {
            address voter = noVotersList[i];
            voters[currentIndex] = VoterInfo({
                voter: voter,
                votingPower: votingPower[proposalId][voter],
                support: false
            });
            currentIndex++;
        }

        return voters;
    }

    // Get user's voting power
    function getUserVotingPower(address user) external view returns (uint256) {
        return lockedIDRX[user];
    }

    // Get proposal count
    function getProposalCount() external view returns (uint256) {
        return communityProposals.length;
    }

    // Check if user has voted on a proposal
    function hasVoted(
        uint256 proposalId,
        address user
    ) external view returns (bool) {
        return votingPower[proposalId][user] > 0;
    }

    // Get proposal status
    function getProposalStatus(
        uint256 proposalId
    )
        external
        view
        returns (
            bool isActive,
            bool isExecuted,
            bool isApproved,
            bool hasMetQuorum,
            uint256 timeLeft
        )
    {
        require(proposalId < communityProposals.length, "Invalid proposal ID");
        CommunityProposal storage p = communityProposals[proposalId];

        isActive = block.timestamp < p.deadline;
        isExecuted = p.executed;
        isApproved = p.approved;
        hasMetQuorum = (p.totalYesPower + p.totalNoPower) >= p.quorum;
        timeLeft = block.timestamp < p.deadline
            ? p.deadline - block.timestamp
            : 0;

        return (isActive, isExecuted, isApproved, hasMetQuorum, timeLeft);
    }

    modifier validProposalId(uint256 proposalId) {
        require(proposalId < communityProposals.length, "Invalid proposal ID");
        _;
    }

    modifier proposalNotExecuted(uint256 proposalId) {
        require(
            !communityProposals[proposalId].executed,
            "Proposal already executed"
        );
        _;
    }

    // Get all subproposals for a community
    function getSubProposals(
        uint256 communityId
    ) external view returns (SubProposalSummary[] memory) {
        require(
            communityId < communityProposals.length,
            "Invalid community ID"
        );
        SubProposal[] storage subs = communitySubProposals[communityId];
        SubProposalSummary[] memory summaries = new SubProposalSummary[](
            subs.length
        );

        for (uint256 i = 0; i < subs.length; i++) {
            SubProposal storage s = subs[i];
            summaries[i] = SubProposalSummary({
                title: s.title,
                description: s.description,
                proposer: s.proposer,
                requestedAmount: s.requestedAmount,
                yesVotes: s.yesVotes,
                noVotes: s.noVotes,
                totalYesPower: s.totalYesPower,
                totalNoPower: s.totalNoPower,
                approved: s.approved,
                executed: s.executed
            });
        }
        return summaries;
    }

    // Get detailed information about a specific subproposal
    function getSubProposalDetails(
        uint256 communityId,
        uint256 subProposalId
    )
        external
        view
        returns (
            string memory title,
            string memory description,
            address proposer,
            uint256 requestedAmount,
            uint256 yesVotes,
            uint256 noVotes,
            uint256 totalYesPower,
            uint256 totalNoPower,
            bool approved,
            bool executed
        )
    {
        require(
            communityId < communityProposals.length,
            "Invalid community ID"
        );
        require(
            subProposalId < communitySubProposals[communityId].length,
            "Invalid subproposal ID"
        );

        SubProposal storage s = communitySubProposals[communityId][
            subProposalId
        ];

        return (
            s.title,
            s.description,
            s.proposer,
            s.requestedAmount,
            s.yesVotes,
            s.noVotes,
            s.totalYesPower,
            s.totalNoPower,
            s.approved,
            s.executed
        );
    }

    // Get subproposal count for a community
    function getSubProposalCount(
        uint256 communityId
    ) external view returns (uint256) {
        require(
            communityId < communityProposals.length,
            "Invalid community ID"
        );
        return communitySubProposals[communityId].length;
    }

    // Get subproposal status
    function getSubProposalStatus(
        uint256 communityId,
        uint256 subProposalId
    )
        external
        view
        returns (
            bool isActive,
            bool isExecuted,
            bool isApproved,
            bool hasMetQuorum,
            uint256 totalVotes
        )
    {
        require(
            communityId < communityProposals.length,
            "Invalid community ID"
        );
        require(
            subProposalId < communitySubProposals[communityId].length,
            "Invalid subproposal ID"
        );

        SubProposal storage s = communitySubProposals[communityId][
            subProposalId
        ];

        isActive = !s.executed;
        isExecuted = s.executed;
        isApproved = s.approved;
        hasMetQuorum =
            (s.totalYesPower + s.totalNoPower) >=
            communityProposals[communityId].quorum;
        totalVotes = s.totalYesPower + s.totalNoPower;

        return (isActive, isExecuted, isApproved, hasMetQuorum, totalVotes);
    }

    // Get all subproposals created by a specific address
    function getUserSubProposals(
        address user
    )
        external
        view
        returns (
            uint256[] memory communityIds,
            uint256[] memory subProposalIds,
            SubProposalSummary[] memory proposals
        )
    {
        uint256 totalCount = 0;

        // First count total subproposals by user
        for (uint256 i = 0; i < communityProposals.length; i++) {
            SubProposal[] storage subs = communitySubProposals[i];
            for (uint256 j = 0; j < subs.length; j++) {
                if (subs[j].proposer == user) {
                    totalCount++;
                }
            }
        }

        // Initialize arrays
        communityIds = new uint256[](totalCount);
        subProposalIds = new uint256[](totalCount);
        proposals = new SubProposalSummary[](totalCount);

        uint256 currentIndex = 0;

        // Fill arrays
        for (uint256 i = 0; i < communityProposals.length; i++) {
            SubProposal[] storage subs = communitySubProposals[i];
            for (uint256 j = 0; j < subs.length; j++) {
                if (subs[j].proposer == user) {
                    communityIds[currentIndex] = i;
                    subProposalIds[currentIndex] = j;
                    proposals[currentIndex] = SubProposalSummary({
                        title: subs[j].title,
                        description: subs[j].description,
                        proposer: subs[j].proposer,
                        requestedAmount: subs[j].requestedAmount,
                        yesVotes: subs[j].yesVotes,
                        noVotes: subs[j].noVotes,
                        totalYesPower: subs[j].totalYesPower,
                        totalNoPower: subs[j].totalNoPower,
                        approved: subs[j].approved,
                        executed: subs[j].executed
                    });
                    currentIndex++;
                }
            }
        }

        return (communityIds, subProposalIds, proposals);
    }
}
