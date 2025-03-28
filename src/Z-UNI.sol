// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {PositionInfo} from "v4-periphery/src/libraries/PositionInfoLibrary.sol";

contract ZUniToken is ERC20, Ownable, ERC20Capped {
    uint immutable cappedTokenSupply = 88000000 * (10**18);

    constructor(
        string memory name,
        string memory symbol, 
        uint decimals,
        address initialOwner_
    )
        ERC20(name, symbol)
        Ownable(initialOwner_)
        ERC20Capped(cappedTokenSupply)
    {}

    /* Convert Liquidity Provider NFT Position to ERC20 tokens */
    function deposit(PositionInfo positionInfo) public returns(uint256 erc20Tokens) {
        // code goes here
    }
    
    /* Overriding function found in both ERC20 & ERC20Capped */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Capped) {
        super._update(from, to, value);
    }
}
