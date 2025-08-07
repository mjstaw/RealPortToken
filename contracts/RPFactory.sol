// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./RPToken.sol";

contract RPFactory is AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Role constants
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // KYC statuses
    enum KycStatus { None, Pending, Approved, Rejected }

    // Project registry
    struct ProjectInfo {
        address token;
        string name;
        string symbol;
        string metadataURI;
        bool active; // NEW: track removal/restoration
    }
    ProjectInfo[] public projects;

    // KYC management
    mapping(address => KycStatus) public kycStatus;
    EnumerableSet.AddressSet private pendingKycRequests;

    // Admin enumeration
    EnumerableSet.AddressSet private adminSet;

    // Events
    event ProjectCreated(address indexed token, string name, string symbol, string metadataURI, uint256 index);
    event ProjectRemoved(uint256 index, address token);
    event ProjectRestored(uint256 index, address token);
    event ProjectMetadataUpdated(uint256 index, string newMetadataURI);

    event KycRequested(address indexed user);
    event KycApproved(address indexed user);
    event KycRejected(address indexed user);
    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender); // auto-minter for deployer

        // Add deployer to admin set
        adminSet.add(msg.sender);

        // Factory auto-approved for KYC
        kycStatus[address(this)] = KycStatus.Approved;
        // Auto-approve deployer EOA
        kycStatus[msg.sender] = KycStatus.Approved;
    }

    // ----- Role Accessors for External Contracts -----
    function getMinterRole() external pure returns (bytes32) {
        return MINTER_ROLE;
    }

    function getAdminRole() external pure returns (bytes32) {
        return ADMIN_ROLE;
    }

    // ----- Admin Enumeration -----
    function getAllAdmins() external view returns (address[] memory) {
        return adminSet.values();
    }

    // ----- Admin & Role Management -----
    function addAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
        adminSet.add(account);
        emit AdminAdded(account);
    }

    function removeAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
        adminSet.remove(account);
        emit AdminRemoved(account);
    }

    function addMinter(address account) external onlyRole(ADMIN_ROLE) {
        grantRole(MINTER_ROLE, account);
    }

    function removeMinter(address account) external onlyRole(ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, account);
    }

    // ----- KYC Management for EOAs -----
    function requestKyc() external {
        require(kycStatus[msg.sender] == KycStatus.None, "Already requested/handled");
        kycStatus[msg.sender] = KycStatus.Pending;
        pendingKycRequests.add(msg.sender);
        emit KycRequested(msg.sender);
    }

    function approveKyc(address user) external onlyRole(ADMIN_ROLE) {
        require(user != address(0), "Invalid address");
        kycStatus[user] = KycStatus.Approved;
        pendingKycRequests.remove(user); // safe no-op if not pending
        emit KycApproved(user);
    }

    function rejectKyc(address user) external onlyRole(ADMIN_ROLE) {
        require(kycStatus[user] == KycStatus.Pending, "Not pending");
        kycStatus[user] = KycStatus.Rejected;
        pendingKycRequests.remove(user);
        emit KycRejected(user);
    }

    function getPendingKycRequests() external view onlyRole(ADMIN_ROLE) returns (address[] memory) {
        return pendingKycRequests.values();
    }

    function isKycApproved(address user) external view returns (bool) {
        return kycStatus[user] == KycStatus.Approved;
    }

    // ----- Project Deployment -----
    function createProjectToken(
        string memory name,
        string memory symbol,
        string memory metadataURI,
        uint256 initialSupply
    ) external onlyRole(ADMIN_ROLE) returns (address) {
        RPToken token = new RPToken(name, symbol, initialSupply, address(this));
        projects.push(ProjectInfo(address(token), name, symbol, metadataURI, true));
        emit ProjectCreated(address(token), name, symbol, metadataURI, projects.length - 1);
        return address(token);
    }

    // ----- Project Management -----
    function updateProjectMetadata(uint256 index, string calldata newMetadataURI)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(index < projects.length, "Invalid index");
        projects[index].metadataURI = newMetadataURI;
        emit ProjectMetadataUpdated(index, newMetadataURI);
    }

    function removeProject(uint256 index) external onlyRole(ADMIN_ROLE) {
        require(index < projects.length, "Invalid index");
        require(projects[index].active, "Already inactive");
        projects[index].active = false;
        emit ProjectRemoved(index, projects[index].token);
    }

    function restoreProject(address token) external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < projects.length; i++) {
            if (projects[i].token == token) {
                projects[i].active = true;
                emit ProjectRestored(i, token);
                return;
            }
        }
        revert("Token not found");
    }

    // ----- Views -----
    function projectsCount() external view returns (uint256) {
        return projects.length;
    }

    function getProject(uint256 index) external view returns (ProjectInfo memory) {
        require(index < projects.length, "Invalid index");
        return projects[index];
    }

    function getAllProjects() external view returns (ProjectInfo[] memory) {
        return projects;
    }

    function getActiveProjects() external view returns (ProjectInfo[] memory) {
        uint256 count;
        for (uint256 i = 0; i < projects.length; i++) {
            if (projects[i].active) count++;
        }
        ProjectInfo[] memory activeProjects = new ProjectInfo[](count);
        uint256 j;
        for (uint256 i = 0; i < projects.length; i++) {
            if (projects[i].active) {
                activeProjects[j] = projects[i];
                j++;
            }
        }
        return activeProjects;
    }

    // ----- Role Query For Tokens/Marketplace -----
    function hasRoleInFactory(bytes32 role, address account) external view returns (bool) {
        return hasRole(role, account);
    }
}
