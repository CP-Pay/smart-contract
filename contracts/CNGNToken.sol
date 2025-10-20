// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title CNGNToken
 * @notice Stable token representing Nigerian Naira balances bridged via CPPay.
 */
contract CNGNToken is ERC20Burnable, AccessControl {
	bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

	constructor(address admin) ERC20("CPPay NGN", "cNGN") {
		require(admin != address(0), "CNGN: admin zero");
		_grantRole(DEFAULT_ADMIN_ROLE, admin);
	}

	function grantBridge(address bridge) external onlyRole(DEFAULT_ADMIN_ROLE) {
		_grantRole(BRIDGE_ROLE, bridge);
	}

	function revokeBridge(address bridge) external onlyRole(DEFAULT_ADMIN_ROLE) {
		_revokeRole(BRIDGE_ROLE, bridge);
	}

	function mint(address to, uint256 amount) external onlyRole(BRIDGE_ROLE) {
		_mint(to, amount);
	}

	function burnFrom(address account, uint256 amount) public override onlyRole(BRIDGE_ROLE) {
		super.burnFrom(account, amount);
	}

	function supportsInterface(bytes4 interfaceId)
		public
		view
		override(AccessControl)
		returns (bool)
	{
		return super.supportsInterface(interfaceId);
	}
}
