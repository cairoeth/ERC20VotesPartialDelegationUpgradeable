// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {TestHarness} from "./helpers/TestHarness.sol";
import {L2GovToken} from "../src/L2GovToken.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {PartialDelegation, DelegationAdjustment} from "../src/IVotesPartialDelegation.sol";
import {FakeERC20VotesPartialDelegationUpgradeable} from "./fakes/FakeERC20VotesPartialDelegationUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract L2GovTest is TestHarness {
  address admin = makeAddr("admin");
  address minter = makeAddr("minter");
  address burner = makeAddr("burner");

  function setUp() public override {
    super.setUp();
    tokenProxy.initialize(admin);
    vm.startPrank(admin);
    tokenProxy.grantRole(tokenProxy.MINTER_ROLE(), minter);
    tokenProxy.grantRole(tokenProxy.BURNER_ROLE(), burner);
    vm.stopPrank();
  }
}

contract L2GovTestPreInit is TestHarness {
  function setUp() public override {
    tokenImpl = new FakeERC20VotesPartialDelegationUpgradeable();
    tokenProxy = FakeERC20VotesPartialDelegationUpgradeable(address(new ERC1967Proxy(address(tokenImpl), "")));
  }
}

contract Initialize is L2GovTestPreInit {
  /// @notice Emitted when address zero is provided as admin.
  error InvalidAddressZero();

  function testInitialize(address _admin) public {
    vm.assume(_admin != address(0));
    assertEq(tokenProxy.name(), "");
    assertEq(tokenProxy.symbol(), "");
    tokenProxy.initialize(_admin);
    assertEq(tokenProxy.name(), "L2 Governance Token");
    assertEq(tokenProxy.symbol(), "gL2");
  }

  function test_RevertIf_InitializeTwice(address _admin) public {
    vm.assume(_admin != address(0));
    tokenProxy.initialize(_admin);
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    tokenProxy.initialize(_admin);
  }

  function test_RevertIf_InvalidAddressZero() public {
    vm.expectRevert(InvalidAddressZero.selector);
    tokenProxy.initialize(address(0));
  }
}

contract Mint is L2GovTest {
  function testFuzz_Mints(address _actor, address _account, uint208 _amount) public {
    vm.assume(_actor != address(0));
    vm.assume(_account != address(0));
    vm.startPrank(admin);
    tokenProxy.grantRole(tokenProxy.MINTER_ROLE(), _actor);
    vm.stopPrank();
    vm.prank(_actor);
    tokenProxy.mint(_account, _amount);
    assertEq(tokenProxy.balanceOf(_account), _amount);
  }

  function testFuzz_EmitsDelegateVotesChanged(address _actor, address _account, uint208 _amount) public {
    vm.assume(_actor != address(0));
    vm.assume(_account != address(0));
    vm.startPrank(admin);
    tokenProxy.grantRole(tokenProxy.MINTER_ROLE(), _actor);
    vm.stopPrank();

    PartialDelegation[] memory _toDelegations = _createValidPartialDelegation(0, uint256(keccak256(abi.encode(_actor))));
    vm.prank(_account);
    tokenProxy.delegate(_toDelegations);

    _expectEmitDelegateVotesChangedEvents(_amount, tokenProxy.delegates(address(0)), _toDelegations);
    vm.prank(_actor);
    tokenProxy.mint(_account, _amount);
  }

  function testFuzz_RevertIf_NotMinter(address _actor, address _account, uint208 _amount) public {
    vm.assume(_account != address(0));
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, _actor, tokenProxy.MINTER_ROLE())
    );
    vm.prank(_actor);
    tokenProxy.mint(_account, _amount);
  }
}

contract Burn is L2GovTest {
  function testFuzz_Burns(address _actor, address _account, uint208 _amount) public {
    vm.assume(_actor != address(0));
    vm.assume(_account != address(0));
    vm.startPrank(admin);
    tokenProxy.grantRole(tokenProxy.BURNER_ROLE(), _actor);
    vm.stopPrank();
    vm.prank(minter);
    tokenProxy.mint(_account, _amount);
    vm.prank(_actor);
    tokenProxy.burn(_account, _amount);
    assertEq(tokenProxy.balanceOf(_account), 0);
  }

  function testFuzz_EmitsDelegateVotesChanged(address _actor, address _account, uint208 _amount) public {
    vm.assume(_actor != address(0));
    vm.assume(_account != address(0));
    vm.startPrank(admin);
    tokenProxy.grantRole(tokenProxy.BURNER_ROLE(), _actor);
    vm.stopPrank();
    vm.prank(minter);
    tokenProxy.mint(_account, _amount);

    PartialDelegation[] memory _fromDelegations =
      _createValidPartialDelegation(0, uint256(keccak256(abi.encode(_actor))));
    vm.prank(_account);
    tokenProxy.delegate(_fromDelegations);

    _expectEmitDelegateVotesChangedEvents(_amount, _fromDelegations, tokenProxy.delegates(address(0)));
    vm.prank(_actor);
    tokenProxy.burn(_account, _amount);
  }

  function testFuzz_RevertIf_NotBurner(address _actor, address _account, uint208 _amount) public {
    vm.assume(_account != address(0));
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, _actor, tokenProxy.BURNER_ROLE())
    );
    vm.prank(_actor);
    tokenProxy.burn(_account, _amount);
  }
}
