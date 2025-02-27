// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";

import { CommonBase } from "forge-std/Base.sol";
import { UD2x18 } from "prb-math/UD2x18.sol";
import { SD1x18 } from "prb-math/SD1x18.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

import { PrizePool, ConstructorParams } from "../../../src/PrizePool.sol";
import { ERC20Mintable } from "../../mocks/ERC20Mintable.sol";

contract PrizePoolFuzzHarness is CommonBase {
  PrizePool public prizePool;
  ERC20Mintable public token;

  uint public contributed;
  uint public withdrawn;
  uint public claimed;

  constructor() {
    address drawManager = address(this);
    uint32 drawPeriodSeconds = 1 hours;
    uint64 nextDrawStartsAt = uint64(block.timestamp);
    uint8 numberOfTiers = 3;
    uint8 tierShares = 100;
    uint8 canaryShares = 10;
    uint8 reserveShares = 10;
    UD2x18 claimExpansionThreshold = UD2x18.wrap(0.9e18);
    SD1x18 smoothing = SD1x18.wrap(0.9e18);

    token = new ERC20Mintable("name", "SYMBOL");
    TwabController twabController = new TwabController(drawPeriodSeconds, uint32(block.timestamp));
    // arbitrary mint
    twabController.mint(address(this), 100e18);

    ConstructorParams memory params = ConstructorParams(
      token,
      twabController,
      drawManager,
      drawPeriodSeconds,
      nextDrawStartsAt,
      numberOfTiers,
      tierShares,
      canaryShares,
      reserveShares,
      claimExpansionThreshold,
      smoothing
    );
    prizePool = new PrizePool(params);
  }

  function contributePrizeTokens(uint64 _amount) public {
    contributed += _amount;
    token.mint(address(prizePool), _amount);
    prizePool.contributePrizeTokens(address(this), _amount);
  }

  function withdrawReserve(uint64 amount) public {
    withdrawn += amount;
    vm.assume(amount <= prizePool.reserve());
    prizePool.withdrawReserve(address(msg.sender), uint104(amount));
  }

  function claimPrizes() public {
    for (uint8 i = 0; i < prizePool.numberOfTiers(); i++) {
      for (uint32 p = 0; p < prizePool.getTierPrizeCount(i); i++) {
        if (
          prizePool.isWinner(address(this), address(this), i, p) &&
          !prizePool.wasClaimed(address(this), address(this), i, p)
        ) {
          claimed += prizePool.claimPrize(address(this), i, p, address(this), 0, address(0));
        }
      }
    }
  }

  function closeDraw() public {
    prizePool.closeDraw(uint256(keccak256(abi.encode(block.timestamp))));
  }
}
