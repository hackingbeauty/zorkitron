// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC20 is ERC20, ERC20Pausable, ERC20Burnable, Ownable {
    uint8 public immutable DECIMALS;

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _initialSupply) 
        ERC20(_name, _symbol) 
        Ownable(msg.sender)
    {
        _mint(msg.sender, _initialSupply);
        DECIMALS = _decimals;
    }

    function decimals() public view override returns(uint8) {
        return DECIMALS;
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyOwner {
        _burn(_from, _amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }

}