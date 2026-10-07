// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {LaunchToken} from "src/LaunchToken.sol";

/// @dev Local token tests; no official factory, quote or payment verification is simulated.
contract LaunchTokenAdversarialTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000 ether;
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    address private constant SPENDER = address(0x5EED);
    address private constant OTHER = address(0xBAD);
    address private constant ISSUER = 0x1C651928150DADDDA9C2C040a9D4901d862f8eC4;

    LaunchToken private token;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        vm.chainId(1);
        token = new LaunchToken();
    }

    function test_oneWeiAndFullSupplyRoundTrips() public {
        uint256[3] memory amounts = [uint256(1), SUPPLY - 1, SUPPLY];
        for (uint256 i; i < amounts.length; ++i) {
            uint256 amount = amounts[i];
            assertTrue(token.transfer(ALICE, amount));
            assertEq(token.balanceOf(ALICE), amount);
            vm.prank(ALICE);
            assertTrue(token.transfer(address(this), amount));
            assertEq(token.balanceOf(address(this)), SUPPLY);
            assertEq(token.balanceOf(ALICE), 0);
            _expectBalanceFailure(ALICE, BOB, 1);
        }
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_zeroTransferFromWithoutApprovalEmitsTransfer() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(ALICE, BOB, 0);
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(ALICE, BOB, 0));
        assertEq(token.allowance(ALICE, SPENDER), 0);
        assertEq(token.balanceOf(ALICE), 0);
        assertEq(token.balanceOf(BOB), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    function test_selfTransferFromConsumesAllowanceWithoutMovingBalance() public {
        token.transfer(ALICE, 7);
        vm.prank(ALICE);
        token.approve(SPENDER, 8);
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(ALICE, ALICE, 7);
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(ALICE, ALICE, 7));
        assertEq(token.balanceOf(ALICE), 7);
        assertEq(token.allowance(ALICE, SPENDER), 1);

        vm.prank(ALICE);
        token.approve(SPENDER, 8);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, ALICE, 7, 8));
        vm.prank(SPENDER);
        token.transferFrom(ALICE, ALICE, 8);
        assertEq(token.allowance(ALICE, SPENDER), 8);
        assertEq(token.balanceOf(ALICE), 7);
    }

    function test_holderMustApproveItselfToUseTransferFrom() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, 1));
        token.transferFrom(address(this), BOB, 1);
        token.approve(address(this), 1);
        assertTrue(token.transferFrom(address(this), BOB, 1));
        assertEq(token.allowance(address(this), address(this)), 0);
        assertEq(token.balanceOf(BOB), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
    }

    function test_approvalIsIsolatedByOwnerAndSpender() public {
        token.transfer(ALICE, 10);
        token.transfer(BOB, 10);
        vm.prank(ALICE);
        token.approve(SPENDER, 8);
        vm.prank(BOB);
        token.approve(OTHER, 9);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, OTHER, 0, 1));
        vm.prank(OTHER);
        token.transferFrom(ALICE, OTHER, 1);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, SPENDER, 0, 1));
        vm.prank(SPENDER);
        token.transferFrom(BOB, SPENDER, 1);

        vm.prank(SPENDER);
        assertTrue(token.transferFrom(ALICE, SPENDER, 8));
        assertEq(token.balanceOf(ALICE), 2);
        assertEq(token.balanceOf(SPENDER), 8);
        assertEq(token.balanceOf(BOB), 10);
        assertEq(token.balanceOf(OTHER), 0);
        assertEq(token.allowance(ALICE, SPENDER), 0);
        assertEq(token.allowance(BOB, OTHER), 9);
        assertEq(token.allowance(ALICE, OTHER), 0);
        assertEq(token.allowance(BOB, SPENDER), 0);
    }

    function test_issuerAndTransactionOriginHaveNoSpendingPrivilege() public {
        // Even the issuing wallet and constructor caller cannot spend another holder's tokens.
        token.transfer(ALICE, 10);
        token.approve(SPENDER, type(uint256).max);
        address[3] memory callers = [ISSUER, address(this), SPENDER];
        for (uint256 i; i < callers.length; ++i) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, callers[i], 0, 1));
            vm.prank(callers[i], ALICE);
            token.transferFrom(ALICE, callers[i], 1);
        }
        assertEq(token.balanceOf(ALICE), 10);
        assertEq(token.balanceOf(ISSUER), 0);
        assertEq(token.balanceOf(SPENDER), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - 10);
    }

    function test_maxMinusOneAllowanceIsFinite() public {
        token.approve(SPENDER, type(uint256).max - 1);
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(address(this), ALICE, 1));
        assertEq(token.allowance(address(this), SPENDER), type(uint256).max - 2);
        assertEq(token.balanceOf(ALICE), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
    }

    function test_infiniteApprovalCanBeReducedAndRevokedAfterSpending() public {
        token.approve(SPENDER, type(uint256).max);
        vm.prank(SPENDER);
        token.transferFrom(address(this), ALICE, 1);
        assertEq(token.allowance(address(this), SPENDER), type(uint256).max);
        token.approve(SPENDER, 1);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, SPENDER, 1, 2));
        vm.prank(SPENDER);
        token.transferFrom(address(this), ALICE, 2);
        token.approve(SPENDER, 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, SPENDER, 0, 1));
        vm.prank(SPENDER);
        token.transferFrom(address(this), ALICE, 1);
        assertEq(token.allowance(address(this), SPENDER), 0);
        assertEq(token.balanceOf(ALICE), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
    }

    function test_maximumTransferAndDelegatedTransferRevertAtomically() public {
        _expectBalanceFailure(address(this), ALICE, type(uint256).max);
        token.approve(SPENDER, type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, type(uint256).max
            )
        );
        vm.prank(SPENDER);
        token.transferFrom(address(this), ALICE, type(uint256).max);
        assertEq(token.allowance(address(this), SPENDER), type(uint256).max);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(ALICE), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_zeroReceiverCannotBurnThroughTransferFrom() public {
        uint256[3] memory amounts = [uint256(0), uint256(1), SUPPLY];
        for (uint256 i; i < amounts.length; ++i) {
            token.approve(SPENDER, amounts[i]);
            vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
            vm.prank(SPENDER);
            token.transferFrom(address(this), address(0), amounts[i]);
            assertEq(token.allowance(address(this), SPENDER), amounts[i]);
            assertEq(token.totalSupply(), SUPPLY);
            assertEq(token.balanceOf(address(this)), SUPPLY);
            assertEq(token.balanceOf(address(0)), 0);
        }
    }

    function test_zeroSpenderRejectedEvenForZeroApproval() public {
        token.approve(SPENDER, 7);
        uint256[3] memory amounts = [uint256(0), uint256(1), type(uint256).max];
        for (uint256 i; i < amounts.length; ++i) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
            token.approve(address(0), amounts[i]);
            assertEq(token.allowance(address(this), address(0)), 0);
            assertEq(token.allowance(address(this), SPENDER), 7);
        }
    }

    function test_constructorAndMutationFunctionsRejectNativeValue() public {
        vm.deal(address(this), 10);
        bytes memory code = type(LaunchToken).creationCode;
        address deployed;
        assembly ("memory-safe") {
            deployed := create(1, add(code, 32), mload(code))
        }
        assertEq(deployed, address(0), "constructor accepted ETH");
        assertEq(address(this).balance, 10);

        token.approve(address(this), 1);
        bytes[3] memory calls = [
            abi.encodeCall(token.transfer, (ALICE, 1)),
            abi.encodeCall(token.approve, (SPENDER, 1)),
            abi.encodeCall(token.transferFrom, (address(this), ALICE, 1))
        ];
        for (uint256 i; i < calls.length; ++i) {
            (bool ok,) = address(token).call{value: 1}(calls[i]);
            assertFalse(ok, "ERC20 method accepted ETH");
        }
        assertEq(address(this).balance, 10);
        assertEq(address(token).balance, 0);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(ALICE), 0);
        assertEq(token.allowance(address(this), address(this)), 1);
        assertEq(token.allowance(address(this), SPENDER), 0);
    }

    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_overBalanceTransferCannotMoveOrCreateValue(uint256 balanceSeed, uint256 amountSeed) public {
        uint256 balance = bound(balanceSeed, 0, SUPPLY);
        token.transfer(ALICE, balance);
        uint256 amount = bound(amountSeed, balance + 1, type(uint256).max);
        _expectBalanceFailure(ALICE, BOB, amount);
        assertEq(token.balanceOf(ALICE), balance);
        assertEq(token.balanceOf(BOB), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - balance);
        assertEq(token.totalSupply(), SUPPLY);
    }

    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_failedDelegatedSpendPreservesApproval(uint256 balanceSeed, uint256 amountSeed, bool infinite)
        public
    {
        uint256 balance = bound(balanceSeed, 0, SUPPLY);
        uint256 amount = bound(amountSeed, balance + 1, type(uint256).max);
        uint256 approval = infinite ? type(uint256).max : amount;
        token.transfer(ALICE, balance);
        vm.prank(ALICE);
        token.approve(SPENDER, approval);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, ALICE, balance, amount));
        vm.prank(SPENDER);
        token.transferFrom(ALICE, BOB, amount);
        assertEq(token.allowance(ALICE, SPENDER), approval);
        assertEq(token.balanceOf(ALICE), balance);
        assertEq(token.balanceOf(BOB), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - balance);
        assertEq(token.totalSupply(), SUPPLY);
    }

    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_repeatedApprovalReplacesRatherThanAccumulates(uint256 first, uint256 replacement) public {
        token.approve(SPENDER, first);
        token.approve(SPENDER, replacement);
        token.approve(SPENDER, replacement);
        assertEq(token.allowance(address(this), SPENDER), replacement);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(SPENDER), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function _expectBalanceFailure(address from, address to, uint256 amount) private {
        uint256 beforeFrom = token.balanceOf(from);
        uint256 beforeTo = token.balanceOf(to);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, from, beforeFrom, amount)
        );
        vm.prank(from);
        token.transfer(to, amount);
        assertEq(token.balanceOf(from), beforeFrom);
        assertEq(token.balanceOf(to), beforeTo);
    }
}
