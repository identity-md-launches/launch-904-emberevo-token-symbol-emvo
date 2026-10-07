// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {LaunchToken} from "../src/LaunchToken.sol";

/// @dev Exercises successful and rejected ERC-20 calls across a closed set of holders.
/// Expected balances/allowances are derived from requested operations, never resynced
/// from token getters. A rejected operation must leave that independent ledger intact.
contract TokenHandler is Test {
    uint256 private constant SUPPLY = 1_000_000_000 ether;
    LaunchToken private immutable token;
    address[4] private actors =
        [address(0xA11CE), address(0xB0B), address(0xCAFE), 0x1C651928150DADDDA9C2C040a9D4901d862f8eC4];
    mapping(address => uint256) public expectedBalance;
    mapping(address => mapping(address => uint256)) public expectedAllowance;

    constructor(LaunchToken token_) {
        token = token_;
        expectedBalance[actors[0]] = SUPPLY;
    }

    function actor(uint256 index) external view returns (address) {
        return actors[index];
    }

    function move(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 amount = bound(amountSeed, 0, expectedBalance[from]);
        _move(from, to, amount);
    }

    function moveFullBalance(uint256 fromSeed, uint256 toSeed) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        _move(from, to, expectedBalance[from]);
    }

    function _move(address from, address to, uint256 amount) private {
        uint256 beforeFrom = token.balanceOf(from);
        uint256 beforeTo = token.balanceOf(to);
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
        expectedBalance[from] -= amount;
        expectedBalance[to] += amount;
        _assertBalances(from, to, beforeFrom, beforeTo, amount);
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        _approve(owner, spender, amount);
    }

    function boundaryApproval(uint256 ownerSeed, uint256 spenderSeed, uint256 mode) external {
        uint256[4] memory amounts = [uint256(0), uint256(1), type(uint256).max - 1, type(uint256).max];
        _approve(actors[ownerSeed % actors.length], actors[spenderSeed % actors.length], amounts[mode % 4]);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
        expectedAllowance[owner][spender] = amount;
        assertEq(token.allowance(owner, spender), amount);
    }

    function spend(uint256 fromSeed, uint256 toSeed, uint256 spenderSeed, uint256 amountSeed) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        uint256 allowance = expectedAllowance[from][spender];
        uint256 beforeFrom = token.balanceOf(from);
        uint256 beforeTo = token.balanceOf(to);
        uint256 balance = expectedBalance[from];
        uint256 maximum = balance < allowance ? balance : allowance;
        uint256 amount = bound(amountSeed, 0, maximum);
        vm.prank(spender);
        assertTrue(token.transferFrom(from, to, amount));
        expectedBalance[from] -= amount;
        expectedBalance[to] += amount;
        if (allowance != type(uint256).max) expectedAllowance[from][spender] -= amount;
        _assertBalances(from, to, beforeFrom, beforeTo, amount);
        assertEq(token.allowance(from, spender), allowance == type(uint256).max ? allowance : allowance - amount);
    }

    function rejectOverBalanceTransfer(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 balance = expectedBalance[from];
        uint256 amount = bound(amountSeed, balance + 1, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, from, balance, amount));
        vm.prank(from);
        token.transfer(to, amount);
    }

    function rejectOverAllowanceSpend(uint256 ownerSeed, uint256 spenderSeed, uint256 approvalSeed) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        uint256 approval = bound(approvalSeed, 0, SUPPLY);
        _approve(owner, spender, approval);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, approval, approval + 1)
        );
        vm.prank(spender);
        token.transferFrom(owner, spender, approval + 1);
    }

    function rejectOverBalanceSpend(uint256 ownerSeed, uint256 spenderSeed, bool infinite) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        uint256 balance = expectedBalance[owner];
        uint256 amount = balance + 1;
        _approve(owner, spender, infinite ? type(uint256).max : amount);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, owner, balance, amount));
        vm.prank(spender);
        token.transferFrom(owner, spender, amount);
    }

    function rejectZeroReceiver(uint256 ownerSeed, uint256 spenderSeed, uint256 amountSeed) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        uint256 amount = bound(amountSeed, 0, expectedBalance[owner]);
        _approve(owner, spender, amount);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(owner, address(0), amount);
    }

    function advanceTime(uint256 secondsSeed, uint256 blocksSeed) external {
        vm.warp(block.timestamp + bound(secondsSeed, 0, 365 days));
        vm.roll(block.number + bound(blocksSeed, 0, 1_000_000));
    }

    function _assertBalances(address from, address to, uint256 beforeFrom, uint256 beforeTo, uint256 amount)
        private
        view
    {
        if (from == to) {
            assertEq(token.balanceOf(from), beforeFrom);
        } else {
            assertEq(token.balanceOf(from), beforeFrom - amount);
            assertEq(token.balanceOf(to), beforeTo + amount);
        }
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 96
/// forge-config: default.invariant.fail-on-revert = true
contract LaunchTokenInvariantTest is Test {
    LaunchToken private token;
    TokenHandler private handler;

    function setUp() public {
        vm.chainId(1);
        token = new LaunchToken();
        handler = new TokenHandler(token);
        assertTrue(token.transfer(handler.actor(0), 1_000_000_000 ether));

        bytes4[] memory selectors = new bytes4[](10);
        selectors[0] = TokenHandler.move.selector;
        selectors[1] = TokenHandler.approve.selector;
        selectors[2] = TokenHandler.spend.selector;
        selectors[3] = TokenHandler.moveFullBalance.selector;
        selectors[4] = TokenHandler.boundaryApproval.selector;
        selectors[5] = TokenHandler.rejectOverBalanceTransfer.selector;
        selectors[6] = TokenHandler.rejectOverAllowanceSpend.selector;
        selectors[7] = TokenHandler.rejectOverBalanceSpend.selector;
        selectors[8] = TokenHandler.rejectZeroReceiver.selector;
        selectors[9] = TokenHandler.advanceTime.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_supplyAndBalancesAreConserved() public view {
        uint256 sum;
        for (uint256 i; i < 4; ++i) {
            address actor = handler.actor(i);
            uint256 balance = token.balanceOf(actor);
            assertEq(balance, handler.expectedBalance(actor), "holder ledger mismatch");
            sum += balance;
        }
        assertEq(sum, 1_000_000_000 ether);
        assertEq(token.totalSupply(), 1_000_000_000 ether);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(address(handler)), 0);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(token)), 0);
    }

    function invariant_allowancesMatchOnlyAuthorizedChanges() public view {
        for (uint256 i; i < 4; ++i) {
            address owner = handler.actor(i);
            for (uint256 j; j < 4; ++j) {
                address spender = handler.actor(j);
                assertEq(
                    token.allowance(owner, spender),
                    handler.expectedAllowance(owner, spender),
                    "allowance changed without authorization or after a rejected transfer"
                );
            }
            assertEq(token.allowance(owner, address(0)), 0);
            assertEq(token.allowance(owner, address(handler)), 0);
            assertEq(token.allowance(owner, address(this)), 0);
        }
    }

    function invariant_metadataRemainsFixed() public view {
        assertEq(token.name(), "EmberEvo");
        assertEq(token.symbol(), "EMVO");
        assertEq(token.decimals(), 18);
    }

    /// @dev Pins a useful sequence even if random selection happens to miss it.
    function test_handlerSequenceSpendsRevokesRejectsAndRecovers() public {
        handler.move(0, 1, 100);
        handler.approve(1, 2, 60);
        handler.spend(1, 3, 2, 40);
        assertEq(token.balanceOf(handler.actor(3)), 40);
        assertEq(token.allowance(handler.actor(1), handler.actor(2)), 20);
        handler.boundaryApproval(1, 2, 0);
        handler.rejectOverAllowanceSpend(1, 2, 0);
        handler.rejectOverBalanceTransfer(1, 2, type(uint256).max);
        handler.rejectOverBalanceSpend(1, 2, false);
        handler.rejectZeroReceiver(1, 2, 1);
        handler.rejectOverBalanceSpend(1, 2, true);
        handler.advanceTime(365 days, 1_000_000);
        handler.spend(1, 3, 2, 60);
        assertEq(token.allowance(handler.actor(1), handler.actor(2)), type(uint256).max);
        handler.moveFullBalance(3, 0);
        assertEq(token.balanceOf(handler.actor(0)), 1_000_000_000 ether);
        invariant_supplyAndBalancesAreConserved();
        invariant_allowancesMatchOnlyAuthorizedChanges();
        invariant_metadataRemainsFixed();
    }
}
