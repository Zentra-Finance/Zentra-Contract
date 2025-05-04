// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "src/tokens/AdvancedToken.sol"; // adjust path as needed

contract AdvancedTokenTest is Test {
    AdvancedToken public token;

    address constant alice = address(0x1);
    address constant bob = address(0x2);
    address constant router = address(0xD0AAe88AF22dAE89CCF46D9033C2dB6eBf4B87F0);
    address constant reward = address(0x4);

    function setUp() public {
                vm.createSelectFork("https://devnet.dplabs-internal.com");

        vm.deal(alice, 100 ether); // fund Alice
        vm.prank(alice); // next tx from Alice

        AdvancedToken.Args memory args = AdvancedToken.Args({
            name: "Learniverse Token",
            symbol: "LVT",
            _decimals: 18,
            _totalSupply: 1_000_000 ether,
            _serviceFeeReceiver: bob,
            _taxReceiver: bob,
            maxTransaction: 10_000 ether,
            maxWallet: 50_000 ether,
            buyFee: 300, // 3%
            sellFee: 500, // 5%
            dexType: 3,
            dexRouter: router,
            rewardToken: 0,
            buyReward: 100, // 1%
            sellReward: 150, // 1.5%
            lpBuyFee: 200, // 2%
            lpSellFee: 200, // 2%
            buyBurnPercent: 50, // 0.5%
            sellBurnPercent: 75, // 0.75%
            serviceFee: 1 ether
        });

        token = new AdvancedToken{value: 1 ether}(args);
    }

    function testConstructorSetsNameAndSymbol() public {
        assertEq(token.name(), "Learniverse Token");
        assertEq(token.symbol(), "LVT");
    }

    function testOwnerIsAlice() public {
        assertEq(token.owner(), alice);
    }

    function testContractHasReceivedServiceFee() public {
        assertEq(address(token).balance, 1 ether);
    }
}
