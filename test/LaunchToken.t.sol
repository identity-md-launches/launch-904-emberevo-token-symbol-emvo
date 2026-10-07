// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {LaunchToken} from "../src/LaunchToken.sol";

/// @dev Only a constructor-context probe, not an implementation of ProjectFactory.
contract TokenCreationProbe {
    function deploy(bytes32 salt) external returns (LaunchToken) {
        return new LaunchToken{salt: salt}();
    }
}

/// @dev An ordinary ERC-20 transfer must not invoke a recipient hook.
contract RejectingRecipient {
    fallback() external {
        revert("no callbacks");
    }
}

contract LaunchTokenTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 10 ** 18;
    address private constant ISSUER = 0x1C651928150DADDDA9C2C040a9D4901d862f8eC4;
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    address private constant SPENDER = address(0x5EED);

    LaunchToken private token;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        token = new LaunchToken();
    }

    function test_metadataAndEntireInitialSupply() public view {
        assertEq(token.name(), "EmberEvo");
        assertEq(token.symbol(), "EMVO");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(ISSUER), 0);
        assertEq(token.balanceOf(address(0)), 0);
    }

    function test_constructorEmitsSingleMint() public {
        vm.recordLogs();
        LaunchToken deployed = new LaunchToken();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].emitter, address(deployed));
        assertEq(logs[0].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(logs[0].topics[1], bytes32(0));
        assertEq(logs[0].topics[2], bytes32(uint256(uint160(address(this)))));
        assertEq(abi.decode(logs[0].data, (uint256)), SUPPLY);
    }

    function test_create2MintsToFactoryContextWithoutConstructorAllocation() public {
        TokenCreationProbe probe = new TokenCreationProbe();
        bytes32 salt = keccak256("EmberEvo test deployment");
        address predicted = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(bytes1(0xff), address(probe), salt, keccak256(type(LaunchToken).creationCode))
                    )
                )
            )
        );
        LaunchToken deployed = probe.deploy(salt);
        assertEq(address(deployed), predicted);
        assertEq(deployed.balanceOf(address(probe)), SUPPLY);
        assertEq(deployed.balanceOf(address(this)), 0);
        assertEq(deployed.balanceOf(ISSUER), 0);
        assertEq(deployed.totalSupply(), SUPPLY);
    }

    function test_transferEmitsEventAndMovesExactAmount() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(address(this), ALICE, 123 ether);
        assertTrue(token.transfer(ALICE, 123 ether));
        assertEq(token.balanceOf(ALICE), 123 ether);
        assertEq(token.balanceOf(address(this)), SUPPLY - 123 ether);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_requestedAllocationCanBeTransferredExactly() public {
        // These are local recipients, NOT official pool or distributor addresses.
        address pool = address(0x1001);
        address distributor = address(0x1002);
        assertTrue(token.transfer(pool, SUPPLY * 8600 / 10_000));
        assertTrue(token.transfer(distributor, SUPPLY * 1000 / 10_000));
        assertTrue(token.transfer(ISSUER, SUPPLY * 400 / 10_000));
        assertEq(token.balanceOf(pool), 860_000_000 ether);
        assertEq(token.balanceOf(distributor), 100_000_000 ether);
        assertEq(token.balanceOf(ISSUER), 40_000_000 ether);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.totalSupply(), SUPPLY);
        vm.prank(ISSUER);
        assertTrue(token.transfer(ALICE, 40_000_000 ether));
        assertEq(token.balanceOf(ALICE), 40_000_000 ether);
    }

    function test_zeroAndSelfTransfersPreserveBalances() public {
        vm.prank(ALICE);
        assertTrue(token.transfer(BOB, 0));
        assertTrue(token.transfer(address(this), SUPPLY));
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(ALICE), 0);
        assertEq(token.balanceOf(BOB), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferToContractDoesNotInvokeCallback() public {
        RejectingRecipient recipient = new RejectingRecipient();
        assertTrue(token.transfer(address(recipient), 1 ether));
        assertEq(token.balanceOf(address(recipient)), 1 ether);
    }

    function test_transferOverBalanceRevertsWithoutChangingState() public {
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, SUPPLY + 1)
        );
        token.transfer(ALICE, SUPPLY + 1);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(ALICE), 0);
    }

    function test_zeroAddressTransferRevertsEvenForZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 1);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 0);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    function test_approvalEventAndPartialThenFullSpend() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Approval(address(this), SPENDER, 100 ether);
        assertTrue(token.approve(SPENDER, 100 ether));
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(address(this), ALICE, 30 ether));
        assertEq(token.allowance(address(this), SPENDER), 70 ether);
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(address(this), BOB, 70 ether));
        assertEq(token.allowance(address(this), SPENDER), 0);
        assertEq(token.balanceOf(ALICE), 30 ether);
        assertEq(token.balanceOf(BOB), 70 ether);
        assertEq(token.balanceOf(address(this)), SUPPLY - 100 ether);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, SPENDER, 0, 1));
        vm.prank(SPENDER);
        token.transferFrom(address(this), ALICE, 1);
    }

    function test_unapprovedSpenderCannotMoveTokens() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, SPENDER, 0, 1));
        vm.prank(SPENDER);
        token.transferFrom(address(this), ALICE, 1);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(ALICE), 0);
    }

    function test_replacingAndRevokingApproval() public {
        token.approve(SPENDER, 100 ether);
        token.approve(SPENDER, 5 ether);
        assertEq(token.allowance(address(this), SPENDER), 5 ether);
        token.approve(SPENDER, 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, SPENDER, 0, 1));
        vm.prank(SPENDER);
        token.transferFrom(address(this), ALICE, 1);
    }

    function test_approvalToZeroAddressReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), 1);
    }

    function test_failedTransferFromRestoresAllowance() public {
        vm.prank(ALICE);
        token.approve(SPENDER, 10 ether);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, ALICE, 0, 10 ether));
        vm.prank(SPENDER);
        token.transferFrom(ALICE, BOB, 10 ether);
        assertEq(token.allowance(ALICE, SPENDER), 10 ether);
        assertEq(token.balanceOf(BOB), 0);

        token.approve(SPENDER, 10 ether);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(SPENDER);
        token.transferFrom(address(this), address(0), 10 ether);
        assertEq(token.allowance(address(this), SPENDER), 10 ether);
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    function test_infiniteAllowanceFollowsStandardERC20Semantics() public {
        token.approve(SPENDER, type(uint256).max);
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(address(this), ALICE, SUPPLY));
        assertEq(token.allowance(address(this), SPENDER), type(uint256).max);
        assertEq(token.balanceOf(ALICE), SUPPLY);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function test_noMintBurnAdminOrUpgradeEntryPointsForAnyone() public {
        string[20] memory signatures = [
            "mint(address,uint256)",
            "mint(uint256)",
            "mint()",
            "issue(uint256)",
            "burn(uint256)",
            "burnFrom(address,uint256)",
            "owner()",
            "setOwner(address)",
            "transferOwnership(address)",
            "upgradeTo(address)",
            "upgradeToAndCall(address,bytes)",
            "initialize(address)",
            "pause()",
            "unpause()",
            "setMinter(address)",
            "setTax(uint256)",
            "blacklist(address)",
            "rebase(uint256)",
            "stake(uint256)",
            "grantRole(bytes32,address)"
        ];
        address[3] memory callers = [address(this), ISSUER, ALICE];
        for (uint256 c; c < callers.length; ++c) {
            for (uint256 i; i < signatures.length; ++i) {
                vm.prank(callers[c]);
                (bool ok,) = address(token).call(abi.encodeWithSignature(signatures[i], ALICE, 1));
                assertFalse(ok, signatures[i]);
            }
        }
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(ALICE), 0);
        assertEq(token.balanceOf(ISSUER), 0);
    }

    function test_passageOfTimeDoesNotRebaseOrRestrictTransfers() public {
        token.transfer(ALICE, 7 ether);
        vm.warp(block.timestamp + 3650 days);
        vm.roll(block.number + 10_000_000);
        assertEq(token.balanceOf(ALICE), 7 ether);
        assertEq(token.totalSupply(), SUPPLY);
        vm.prank(ALICE);
        assertTrue(token.transfer(BOB, 7 ether));
        assertEq(token.balanceOf(BOB), 7 ether);
    }

    function test_etherAndUnknownCallsRevert() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(token).call{value: 1 ether}("");
        assertFalse(ok);
        (ok,) = address(token).call(hex"deadbeef");
        assertFalse(ok);
        assertEq(address(token).balance, 0);
    }

    function test_runtimeIsBoundedAndHasNoEscapeOpcodes() public view {
        bytes memory code = address(token).code;
        assertGt(code.length, 0);
        assertLe(code.length, 24_576);
        for (uint256 i; i < code.length; ++i) {
            uint8 opcode = uint8(code[i]);
            if (opcode >= 0x60 && opcode <= 0x7f) {
                i += opcode - 0x5f;
                continue;
            }
            assertTrue(opcode != 0xf4 && opcode != 0xf2 && opcode != 0xff, "forbidden opcode");
        }
    }

    function testFuzz_transferRoundTripConservesSupply(uint256 seed) public {
        uint256 amount = bound(seed, 0, SUPPLY);
        assertTrue(token.transfer(ALICE, amount));
        assertEq(token.balanceOf(ALICE), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        vm.prank(ALICE);
        assertTrue(token.transfer(address(this), amount));
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(ALICE), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_allowanceLimitsAreExact(uint256 approvalSeed, uint256 spendSeed) public {
        uint256 approval = bound(approvalSeed, 0, SUPPLY);
        uint256 spend = bound(spendSeed, 0, approval);
        token.approve(SPENDER, approval);
        vm.prank(SPENDER);
        assertTrue(token.transferFrom(address(this), ALICE, spend));
        uint256 remaining = approval - spend;
        assertEq(token.allowance(address(this), SPENDER), remaining);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, SPENDER, remaining, remaining + 1)
        );
        vm.prank(SPENDER);
        token.transferFrom(address(this), ALICE, remaining + 1);
        assertEq(token.allowance(address(this), SPENDER), remaining);
        assertEq(token.balanceOf(ALICE), spend);
        assertEq(token.balanceOf(address(this)), SUPPLY - spend);
    }
}
