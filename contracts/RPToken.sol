// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./RPFactory.sol";

contract RPToken is ERC20 {
    RPFactory public factory;

    string private _name;
    string private _symbol;

    modifier onlyFactoryAdmin() {
        require(factory.hasRoleInFactory(factory.getAdminRole(), msg.sender), "Not factory admin");
        _;
    }

    modifier onlyFactoryMinter() {
        require(factory.hasRoleInFactory(factory.getMinterRole(), msg.sender), "Not factory minter");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        address factory_
    ) ERC20(name_, symbol_) {
        _name = name_;
        _symbol = symbol_;
        factory = RPFactory(factory_);
        _mint(msg.sender, initialSupply);
    }

    // Enforce KYC on all transfers (mint/burn exempt because admin-controlled)
    function _update(address from, address to, uint256 value) internal virtual override {
        if (from != address(0) && to != address(0)) {
            require(factory.isKycApproved(from), "Sender not KYCd");
            require(factory.isKycApproved(to), "Recipient not KYCd");
        }
        super._update(from, to, value);
    }

    function mint(address to, uint256 amount) external onlyFactoryMinter {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyFactoryAdmin {
        _burn(from, amount);
    }

    function setFactory(address newFactory) external onlyFactoryAdmin {
        require(newFactory != address(0), "Zero address");
        factory = RPFactory(newFactory);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }
}
