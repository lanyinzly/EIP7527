// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockToken} from "../mock/CurrencyToken.sol";
import {MembershipApp} from "../../src/boa/MembershipApp.sol";
import {MembershipAgency} from "../../src/boa/MembershipAgency.sol";
import {UsageRegistry} from "../../src/boa/UsageRegistry.sol";

contract MembershipTest is Test {
    MockToken usdc;
    MembershipApp app;
    MembershipAgency agency;
    UsageRegistry registry;

    address feeRecipient = address(0xFEE);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    uint256 constant BASE = 10e6; // 10 USDC (6 decimals)
    uint16 constant MINT_FEE = 500; // 5%
    uint16 constant BURN_FEE = 500; // 5%

    function setUp() public {
        usdc = new MockToken("USD Coin", "USDC");
        app = new MembershipApp("BoA Membership", "BOAM", 1000, "BoA Standard Membership");
        agency = new MembershipAgency(address(app), address(usdc), BASE, feeRecipient, MINT_FEE, BURN_FEE);
        app.setAgency(payable(address(agency)));

        registry = new UsageRegistry(address(this));
        registry.setMembership(address(app));

        usdc.mint(alice, 1_000e6);
        usdc.mint(bob, 1_000e6);
    }

    function _price(uint256 n) internal pure returns (uint256) {
        return BASE + n * BASE / 100;
    }

    function _join(address user) internal returns (uint256 tokenId) {
        uint256 n = app.totalSupply();
        uint256 premium = _price(n);
        uint256 fee = premium * MINT_FEE / 10000;
        vm.startPrank(user);
        usdc.approve(address(agency), premium + fee);
        tokenId = agency.wrap(user, "");
        vm.stopPrank();
    }

    /// Price rises along p(n) and the reserve always equals the sum of premiums paid in.
    function test_WrapPricesFollowCurveAndReserveIsBacked() public {
        uint256 reserve;
        uint256 expectedFees;
        for (uint256 n = 0; n < 5; n++) {
            address user = n % 2 == 0 ? alice : bob;
            _join(user);
            reserve += _price(n);
            expectedFees += _price(n) * MINT_FEE / 10000;
            assertEq(usdc.balanceOf(address(agency)), reserve, "reserve == sum of premiums");
        }
        assertEq(app.totalSupply(), 5, "supply");
        assertEq(usdc.balanceOf(feeRecipient), expectedFees, "fees to recipient");
    }

    /// Exit pays p(n-1) and leaves the reserve exactly backing the remaining members.
    function test_UnwrapIsSolvent() public {
        uint256 id0 = _join(alice);
        uint256 id1 = _join(alice);
        uint256 id2 = _join(alice);
        id0; // silence unused

        uint256 before = usdc.balanceOf(alice);
        vm.prank(alice);
        agency.unwrap(alice, id2, "");

        uint256 premium2 = _price(2); // post-burn supply == 2
        uint256 burnFee = premium2 * BURN_FEE / 10000;
        assertEq(usdc.balanceOf(alice) - before, premium2 - burnFee, "payout follows curve");
        assertEq(usdc.balanceOf(address(agency)), _price(0) + _price(1), "reserve backs remaining members");

        id1; // remaining ids still owned by alice
    }

    /// Usage cannot be recorded for a non-member; once joined, it anchors and aggregates.
    function test_RegistryGatesOnMembership() public {
        registry.setRecorder(address(this), true);

        vm.expectRevert(bytes("UsageRegistry: agent not a member"));
        registry.recordUsage(alice, bytes32("gpt-x"), 1000, 1, bytes32("hcs-seq-1"));

        _join(alice);
        assertTrue(app.isMember(alice), "alice is member");

        uint256 id = registry.recordUsage(alice, bytes32("gpt-x"), 1000, 1, bytes32("hcs-seq-1"));
        assertEq(id, 0, "first record id");
        assertEq(registry.unitsByAgent(alice), 1000, "agent units");
        assertEq(registry.unitsByModel(bytes32("gpt-x")), 1000, "model units");
        assertEq(registry.totalUnits(), 1000, "total units");
    }
}
