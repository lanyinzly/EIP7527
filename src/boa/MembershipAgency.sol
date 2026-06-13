// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC7527Agency, Asset} from "../interfaces/IERC7527Agency.sol";
import {IERC7527App} from "../interfaces/IERC7527App.sol";

/// @title BoA MembershipAgency (USDC FOAMM)
/// @notice USDC-denominated Function-Oracle AMM that prices Bank of Agent memberships. Implements
///         EIP-7527. The price follows f(active supply):
///
///             p(n) = basePremium + n * basePremium / 100
///
///         a reserve-backed linear bonding curve. Because wrap (join) at supply n pays p(n) and
///         unwrap (exit) at supply n pays p(n-1) along the same curve, the reserve held by this
///         contract is always exactly sufficient to unwind every membership — solvent by
///         construction, independent of join/exit order. Protocol fees are skimmed on top and do
///         not touch the reserve.
/// @dev USDC-aware fork of the reference ERC7527Agency: pulls funds via transferFrom on wrap and
///      pays out via safeTransfer on unwrap, instead of using msg.value / sendValue.
contract MembershipAgency is IERC7527Agency {
    using SafeERC20 for IERC20;

    address private immutable _app;
    address private immutable _currency; // USDC
    uint256 private immutable _basePremium;
    address private immutable _feeRecipient;
    uint16 private immutable _mintFeePercent; // out of 10000
    uint16 private immutable _burnFeePercent; // out of 10000

    constructor(
        address app_,
        address currency_,
        uint256 basePremium_,
        address feeRecipient_,
        uint16 mintFeePercent_,
        uint16 burnFeePercent_
    ) {
        require(basePremium_ != 0, "MembershipAgency: zero basePremium");
        require(currency_ != address(0), "MembershipAgency: ETH currency unsupported");
        _app = app_;
        _currency = currency_;
        _basePremium = basePremium_;
        _feeRecipient = feeRecipient_;
        _mintFeePercent = mintFeePercent_;
        _burnFeePercent = burnFeePercent_;
    }

    receive() external payable {}

    function iconstructor() external pure override {}

    function getStrategy()
        public
        view
        override
        returns (address app, Asset memory asset, bytes memory attributeData)
    {
        app = _app;
        asset = Asset(_currency, _basePremium, _feeRecipient, _mintFeePercent, _burnFeePercent);
        attributeData = "";
    }

    function getWrapOracle(bytes memory data) public view override returns (uint256 premium, uint256 fee) {
        uint256 n = abi.decode(data, (uint256));
        premium = _basePremium + n * _basePremium / 100;
        fee = premium * _mintFeePercent / 10000;
    }

    function getUnwrapOracle(bytes memory data) public view override returns (uint256 premium, uint256 fee) {
        uint256 n = abi.decode(data, (uint256));
        premium = _basePremium + n * _basePremium / 100;
        fee = premium * _burnFeePercent / 10000;
    }

    /// @notice Join: pull (premium + mintFee) USDC from the caller, skim the fee to the protocol,
    ///         retain the premium as reserve, and mint a membership to `to`.
    function wrap(address to, bytes calldata data) external payable override returns (uint256 tokenId) {
        uint256 n = IERC721Enumerable(_app).totalSupply();
        (uint256 premium, uint256 mintFee) = getWrapOracle(abi.encode(n));
        IERC20(_currency).safeTransferFrom(msg.sender, address(this), premium + mintFee);
        if (mintFee > 0) {
            IERC20(_currency).safeTransfer(_feeRecipient, mintFee);
        }
        tokenId = IERC7527App(_app).mint(to, data);
        require(n + 1 == IERC721Enumerable(_app).totalSupply(), "MembershipAgency: reentrancy");
        emit Wrap(to, tokenId, premium, mintFee);
    }

    /// @notice Exit: burn the membership, pay (premium - burnFee) USDC from reserve to `to`, and
    ///         skim the burn fee to the protocol. Price uses post-burn supply.
    function unwrap(address to, uint256 tokenId, bytes calldata data) external payable override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "MembershipAgency: not owner nor approved");
        IERC7527App(_app).burn(tokenId, data);
        uint256 n = IERC721Enumerable(_app).totalSupply();
        (uint256 premium, uint256 burnFee) = getUnwrapOracle(abi.encode(n));
        IERC20(_currency).safeTransfer(to, premium - burnFee);
        if (burnFee > 0) {
            IERC20(_currency).safeTransfer(_feeRecipient, burnFee);
        }
        emit Unwrap(to, tokenId, premium, burnFee);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        IERC721Enumerable app_ = IERC721Enumerable(_app);
        address owner = app_.ownerOf(tokenId);
        return spender == owner || app_.isApprovedForAll(owner, spender) || app_.getApproved(tokenId) == spender;
    }
}
