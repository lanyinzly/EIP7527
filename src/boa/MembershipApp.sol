// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC7527App} from "../interfaces/IERC7527App.sol";

/// @title BoA MembershipApp
/// @notice ERC-721 membership pass for Bank of Agent. Holding a token grants ACCESS to the BoA
///         router at the member rate. There is no embedded balance; usage is paid per call (x402)
///         off the NFT. Mint/burn are gated to the Agency (the USDC FOAMM that prices membership).
/// @dev Implements the EIP-7527 App interface so it composes with the existing 7527 stack, but
///      assigns token ids via an internal counter instead of caller-supplied ids.
contract MembershipApp is ERC721Enumerable, IERC7527App {
    address payable private _agency;
    uint256 private immutable _maxSupply;
    uint256 private _nextId;
    string private _membershipName;

    constructor(string memory name_, string memory symbol_, uint256 maxSupply_, string memory membershipName_)
        ERC721(name_, symbol_)
    {
        require(maxSupply_ != 0, "MembershipApp: zero maxSupply");
        _maxSupply = maxSupply_;
        _membershipName = membershipName_;
    }

    modifier onlyAgency() {
        require(msg.sender == _agency, "MembershipApp: only agency");
        _;
    }

    function iconstructor() external override {}

    function getName(uint256) external view override returns (string memory) {
        return _membershipName;
    }

    function getMaxSupply() public view override returns (uint256) {
        return _maxSupply;
    }

    function getAgency() external view override returns (address payable) {
        return _agency;
    }

    function setAgency(address payable agency) external override {
        require(_agency == address(0), "MembershipApp: agency set");
        _agency = agency;
    }

    /// @notice Mint the next membership id to `to`. Ids auto-increment; `data` is reserved for
    ///         future tier encoding and ignored in v1.
    function mint(address to, bytes calldata) external override onlyAgency returns (uint256 tokenId) {
        require(totalSupply() < _maxSupply, "MembershipApp: max supply");
        tokenId = _nextId++;
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId, bytes calldata) external override onlyAgency {
        _burn(tokenId);
    }

    /// @notice Convenience access check used by the router and UsageRegistry.
    function isMember(address account) external view returns (bool) {
        return balanceOf(account) > 0;
    }
}
