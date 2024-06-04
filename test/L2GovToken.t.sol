// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {L2GovToken} from "../src/L2GovToken.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract L2GovTestPreInit is Test {
  L2GovToken public tokenImpl;
  L2GovToken public tokenProxy;

  function setUp() public virtual {
    tokenImpl = new L2GovToken();
    tokenProxy = L2GovToken(address(new ERC1967Proxy(address(tokenImpl), "")));
  }
}

contract L2GovTest is L2GovTestPreInit {
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

  function testFuzz_RevertIf_NotBurner(address _actor, address _account, uint208 _amount) public {
    vm.assume(_account != address(0));
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, _actor, tokenProxy.BURNER_ROLE())
    );
    vm.prank(_actor);
    tokenProxy.burn(_account, _amount);
  }
}
