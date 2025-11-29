// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {OurToken} from "../src/OurToken.sol";
import {ManualToken} from "../src/ManualToken.sol";
import {DeployOurToken} from "../script/DeployOurToken.s.sol";

contract OurTokenTest is Test {
    OurToken public ourToken;
    ManualToken public manualToken;
    DeployOurToken public deployer;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");
    address charlie = makeAddr("charlie");

    uint256 public constant STARTING_BALANCE = 1000 ether;
    uint256 public constant INITIAL_SUPPLY = 1000 ether;

    function setUp() public {
        deployer = new DeployOurToken();
        ourToken = deployer.run();
        manualToken = new ManualToken();

        vm.prank(msg.sender);
        ourToken.transfer(bob, STARTING_BALANCE);
    }

    function testBobBalance() public view {
        assertEq(STARTING_BALANCE, ourToken.balanceOf(bob));
    }

    function testAllowancesWorks() public {
        //transferFrom
        uint256 initialAllowance = 1000;

        //Bob approves Alice to spend tokens on her behalf
        vm.prank(bob);
        ourToken.approve(alice, initialAllowance);

        uint256 transferAmount = 500;
        vm.prank(alice);
        ourToken.transferFrom(bob, alice, transferAmount);

        assertEq(ourToken.balanceOf(alice), transferAmount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
    }

    // Additional OurToken Tests

    function testTokenName() public view {
        assertEq(ourToken.name(), "OurToken");
    }

    function testTokenSymbol() public view {
        assertEq(ourToken.symbol(), "OT");
    }

    function testTokenDecimals() public view {
        assertEq(ourToken.decimals(), 18);
    }

    function testTransferUpdatesBalances() public {
        uint256 transferAmount = 50 ether;
        uint256 initialBobBalance = ourToken.balanceOf(bob);
        uint256 initialAliceBalance = ourToken.balanceOf(alice);

        vm.prank(bob);
        ourToken.transfer(alice, transferAmount);

        assertEq(ourToken.balanceOf(bob), initialBobBalance - transferAmount);
        assertEq(ourToken.balanceOf(alice), initialAliceBalance + transferAmount);
    }

    function testApprovalUpdatesAllowance() public {
        uint256 approvalAmount = 500 ether;

        vm.prank(bob);
        ourToken.approve(alice, approvalAmount);

        assertEq(ourToken.allowance(bob, alice), approvalAmount);
    }

    function testTransferFromReducesAllowance() public {
        uint256 approvalAmount = 500 ether;
        uint256 transferAmount = 200 ether;

        vm.prank(bob);
        ourToken.approve(alice, approvalAmount);

        vm.prank(alice);
        ourToken.transferFrom(bob, charlie, transferAmount);

        assertEq(ourToken.allowance(bob, alice), approvalAmount - transferAmount);
    }

    function testTransferFailsWithInsufficientBalance() public {
        uint256 transferAmount = STARTING_BALANCE + 1 ether;

        vm.prank(bob);
        vm.expectRevert();
        ourToken.transfer(alice, transferAmount);
    }

    function testTransferFromFailsWithInsufficientAllowance() public {
        uint256 transferAmount = 1000 ether;

        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, alice, transferAmount);
    }

    function testTransferFromFailsWithInsufficientBalance() public {
        uint256 approvalAmount = 1000 ether;
        uint256 transferAmount = STARTING_BALANCE + 1 ether;

        vm.prank(bob);
        ourToken.approve(alice, approvalAmount);

        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, charlie, transferAmount);
    }

    function testTransferToZeroAddressFails() public {
        vm.prank(bob);
        vm.expectRevert();
        ourToken.transfer(address(0), 1 ether);
    }

    function testApprovalToZeroAddressFails() public {
        vm.prank(bob);
        vm.expectRevert();
        ourToken.approve(address(0), 1 ether);
    }

    // ManualToken Tests
    function testManualTokenName() public view {
        assertEq(manualToken.name(), "Manual Token");
    }

    function testManualTokenTotalSupply() public view {
        assertEq(manualToken.totalSupply(), 100 ether);
    }

    function testManualTokenDecimals() public view {
        assertEq(manualToken.decimals(), 18);
    }

    function testManualTokenInitialBalance() public view {
        assertEq(manualToken.balanceOf(bob), 0);
        assertEq(manualToken.balanceOf(alice), 0);
    }

    /**
     * explaination of mapping storage manipulation in tests
     * Example with multiple variables:
     *
     *  contract Example {
     * uint256 public count;                        // Slot 0
     * mapping(address => uint256) public balances; // Slot 1
     * string public name;                          // Slot 2
     * }
     *
     * // To access balances[alice]: keccak256(abi.encode(alice, 1))
     * //                                                         ↑
     * //                                            slot number = 1
     *
     * In our case:
     *
     * s_balances is the first (and only) state variable in ManualToken
     * So it gets assigned to storage slot 0
     * That's why we use keccak256(abi.encode(bob, 0))
     *
     *
     */
    function testManualTokenTransfer() public {
        // First we need to give someone tokens to transfer
        // Since ManualToken doesn't have a mint function, we'll use a different approach
        uint256 transferAmount = 50 ether;

        // We'll directly set balance using storage manipulation for testing
        vm.store(
            address(manualToken),
            keccak256(abi.encode(bob, 0)), // 0 means the first slot in the mapping which is the first variable made in the ManualToken contract
            bytes32(transferAmount)
        );

        assertEq(manualToken.balanceOf(bob), transferAmount);

        vm.prank(bob);
        manualToken.transfer(alice, 25 ether);

        assertEq(manualToken.balanceOf(bob), 25 ether);
        assertEq(manualToken.balanceOf(alice), 25 ether);
    }

    function testManualTokenTransferFailsWithInsufficientBalance() public {
        vm.prank(bob);
        vm.expectRevert();
        manualToken.transfer(alice, 1 ether);
    }

    function testManualTokenBalanceConsistency() public {
        uint256 initialAmount = 100 ether;

        // Set initial balance for bob
        vm.store(address(manualToken), keccak256(abi.encode(bob, 0)), bytes32(initialAmount));

        uint256 transferAmount = 30 ether;

        vm.prank(bob);
        manualToken.transfer(alice, transferAmount);

        // Check that total balance is conserved
        assertEq(manualToken.balanceOf(bob) + manualToken.balanceOf(alice), initialAmount);
    }

    function testManualTokenMultipleTransfers() public {
        uint256 initialAmount = 100 ether;

        // Set initial balance for bob
        vm.store(address(manualToken), keccak256(abi.encode(bob, 0)), bytes32(initialAmount));

        vm.prank(bob);
        manualToken.transfer(alice, 30 ether);

        vm.prank(alice);
        manualToken.transfer(charlie, 10 ether);

        assertEq(manualToken.balanceOf(bob), 70 ether);
        assertEq(manualToken.balanceOf(alice), 20 ether);
        assertEq(manualToken.balanceOf(charlie), 10 ether);
    }
}
