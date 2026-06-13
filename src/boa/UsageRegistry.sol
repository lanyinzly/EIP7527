// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IMembership {
    function isMember(address account) external view returns (bool);
}

/// @title BoA UsageRegistry
/// @notice On-chain anchor for attested compute usage — "proof is the leash." Each record links an
///         agent to the model it consumed, the metered units, the amount settled, and an
///         attestation reference (e.g. a Hedera Consensus Service message hash / sequence number).
///         This keeps demand-driven membership pricing tethered to real, proven consumption rather
///         than pure speculation. The aggregates double as a demand signal for the future pricing
///         engine.
/// @dev Writes are restricted to authorized recorders (the router / HCS bridge). If a membership
///      contract is configured, usage can only be recorded for current members.
contract UsageRegistry is Ownable {
    struct UsageRecord {
        address agent;
        bytes32 modelId;
        uint256 units; // metered units (e.g. tokens)
        uint256 amountPaid; // settlement amount in currency base units (informational)
        bytes32 attestation; // HCS message hash / external proof reference
        uint64 timestamp;
    }

    IMembership public membership; // optional gate: require agent is a member
    mapping(address => bool) public recorders; // authorized writers (router / HCS bridge)

    UsageRecord[] public records;
    mapping(address => uint256) public unitsByAgent;
    mapping(bytes32 => uint256) public unitsByModel;
    uint256 public totalUnits;

    event UsageRecorded(
        uint256 indexed id,
        address indexed agent,
        bytes32 indexed modelId,
        uint256 units,
        uint256 amountPaid,
        bytes32 attestation
    );
    event RecorderSet(address indexed recorder, bool allowed);
    event MembershipSet(address indexed membership);

    constructor(address owner_) Ownable(owner_) {}

    modifier onlyRecorder() {
        require(recorders[msg.sender], "UsageRegistry: not recorder");
        _;
    }

    function setRecorder(address recorder, bool allowed) external onlyOwner {
        recorders[recorder] = allowed;
        emit RecorderSet(recorder, allowed);
    }

    function setMembership(address membership_) external onlyOwner {
        membership = IMembership(membership_);
        emit MembershipSet(membership_);
    }

    /// @notice Record a unit of attested usage. This is the on-chain state change that anchors a
    ///         settled, proven inference.
    function recordUsage(address agent, bytes32 modelId, uint256 units, uint256 amountPaid, bytes32 attestation)
        external
        onlyRecorder
        returns (uint256 id)
    {
        if (address(membership) != address(0)) {
            require(membership.isMember(agent), "UsageRegistry: agent not a member");
        }
        id = records.length;
        records.push(UsageRecord(agent, modelId, units, amountPaid, attestation, uint64(block.timestamp)));
        unitsByAgent[agent] += units;
        unitsByModel[modelId] += units;
        totalUnits += units;
        emit UsageRecorded(id, agent, modelId, units, amountPaid, attestation);
    }

    function recordCount() external view returns (uint256) {
        return records.length;
    }
}
