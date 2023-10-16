//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// Contracts to TEST
import "../src/LynxToken.sol";
import "../src/LynxManualProfitSharing.sol";

// Libraries
import "forge-std/Test.sol";

/**
 * THESE TESTS NEED TO BE RUN IN A FORK
 */

contract ProfitSharingTest is Test {
    Lynx public lynx;
    LynxManualProfitDistribution public profitSharing;
    address owner = 0xa1e333e38eC49Fcd0858140018EfcC9c7adAF6bE;

    address[] holders = [
        0xE2fE530C047f2d85298b07D9333C05737f1435fB,
        0x2764822297a7433B9Ecb51EABC38FFBa3B70A059,
        0xD3f107701fbe154866711FDE4b8A3EDA713E0eb3,
        0xb612878AB836f549fcB42B004416346ab0d83d24,
        0x0e76943A45f3DD02EDBD78067930c1bFa8DA96e1,
        0xfbdC4406DF93D63a55a42EBf14728757e70c3EB7,
        0x59471169f62A567EDe841E8128EA730b7588d515,
        0xB77dd6b3ccc68A8209d42E90322B9A119cB2512D,
        0x1FFE54E6689E03B88FD17506C802d71D740c7554,
        0xd5f979E811f37Bc77D817BC71e1F3df771928261,
        0x5013705D6873e58c27c13377B4Ff721F2D8C314B,
        0x5E74676168E17FB2682CeB93e56c37598FEB2653,
        0x2366183938819fC9212A41858a1B9fC4a929d283,
        0x5F1A37A4771C268e8644CA148757d788C3EAdC1C,
        0x62f87d46C41106E2eAC6de491d739a4Ef7eBF214,
        0x576C29E8312Ffc778B864C0e4Bf978822E290770,
        0xFb517C3a49bE755628e971C0c6b49e4dEd1161a4,
        0x144528fB9134c4dea82ea5650FEbADEedA871F9a,
        0x2Bb46dAbDef2cE5CBba7B9258912044112243Cd8,
        0x5f2325875504a0F7D43C81113CcFA42d1BD3CD1b,
        0x30196891F5d6b29fb08466Ff3F2942a2746270d1,
        0x98f4a6325BB290777Db6D876E87BF9664838EB5D,
        0xa30c7210ACe2b2194575Fe5ABD440CDb83CAf4fA,
        0x398239ED84999B5260f1C2faCdE1AA2e766A1b51,
        0x13EBBED9B935f2c985e8331a6e33939eeb2b2930,
        0xE9462926563034Ad7c23059891e6deC2e065d818,
        0x305D5380150D07dae7f0E12B0f10F49144077fFa,
        0xD67E3092F94543FAF7BabAeb91659ef4ca562959,
        0x17411Dc0B922A503456fd93b491f30C325B117Ad,
        0xA69F1a545affd9995D14d1E306c816985229F7B9,
        0x9e45689Dbe65abf7FE366af9eb2Ad7fb41a0cb56,
        0x7496B3EB2a23d5ee2F23a9B29c93e14F1873DF52,
        0xe515145B687e73BbD1C77ce99769dd47Bc7A31D4,
        0x71423253a09EF09603F74F62337475Fb00bbE59E,
        0xd9f6ef33F123BDE21de2d316F3DeFE00da1ddc4f,
        0x767640b5CA546C5882538bE97243C9730DeD25a0,
        0x79a39Bf30DdcCE44ACeCBe2B78a94a067CF20f41,
        0xdD0894283999108d1bF6e4A4464aCB5E03F0810a,
        0x6735f6200e40d59Cd624993aD49fDA9499024965,
        0xAE3384ec8A622C1b80b58204E744Af2DA09A6397,
        0x72111369E698C32b3A7ce153B820856172aBD995,
        0x52464D53DAdF432FA72C9Ca0d92145B3E96216Ea,
        0x9D1B405ACea90C5750BcDaEC000bAdC417E64960,
        0xdf18A1ACD926ADe7CBd53fdb758876d15dD7FB02,
        0x01b1db3bF4B7e88ec14852956cC2492b272e0013,
        0x4451E20834614c8bA30dA11A4d00dA7F557B4108,
        0x6582C1fB5f4d048F71066955060A5D0B6250aAF3,
        0xCb9985b692e712bfD24Fd4f412f2FFd6055E5ee5,
        0x3562e3857ae0cfd826dE6a19346e55Ed87D64b72,
        0xA28bcC7c24a557774C9EcEBF7Db2e1E769f2D38D,
        0x97Afa5DF343AdA0fcc77674cD38beD7DF5C4b4C6,
        0x90AdaC445B594675B7d7E1B90278079666f582C2,
        0x7279EE77111697De75BaB3f06E686f58E1263000,
        0x0dbf5aC01e544Eb61e8dECE5d343F7F4709e73c8,
        0x9Aeb11094652b42D02483EFae2424d28694b7741,
        0xB27Bab5009F7707339c1a9e4eD8A51003dbfA723,
        0x75eE33C1d1415D0D65A77393Be2B847e665202da,
        0xeF3061A81564D8FE71ff88feAaF07a70f35015F1,
        0x75a1Cac6E0687bD18606cF49beA7687917356fdb,
        0xB6478F66dEfff486e92722C1aE5873D663d8aF50,
        0x761365449ff7E07E44f8778C7976Ca4dD1052B77,
        0x1BF01C70F721c2BB5Aee4dBAbb6DeA05A6F844fb,
        0x68d2F2C5D77AAcdE8Df89f1DCDE73211EF38e38b,
        0x8cA6a385A0fa3281ca5729FfAf5a27A899eBDd18,
        0x262FCAB862B3ce82bCDC5C38743303783b416408,
        0x29774b034F4Af0EE6e4cf8821c58C4031f59de03,
        0x986892962D0942476c7A0C9e57fC3977d9C7446C,
        0xd2145A5dfdbe6ED3F92dB4946f1bEd4Ffa2f78dc,
        0xB0c7512161d2Dcb2C3776F58e07588f7a1E5610D,
        0x15812C7b7238E13E2339F51847b670B7668406Ae,
        0x9ca3fC0c46eF1AD52C7DdC836606370e912F40e5,
        0xC027e37504ad5b0713cFb542044d488e917b2fE1,
        0x068C53aaFBFEB51bf1E75b88f16aF22B448F8E8c,
        0x67eCa156D541829381909a9E59dc02e6E5d8BD78,
        0x9a5ce84693a43543b001ae925b327B9959c089D2,
        0x2fE2f0F5C23074ACb4301C04673678d51C1f1E19,
        0xB4ad2885ba93301ca70402c0d0C99DD117E89A07,
        0xfa71C65Ea53ea795075D4b1464831DbFFD4579D1,
        0xA990a914f668Bd88350D82Ff6B5FeC3a165B32C6,
        0x244B4513A8B87c1aBe114DDA9e3203E2Ae2527a5,
        0x2B1ab5bDD236b301BC5f6F2F707eC14D11f1852C,
        0xE890dF860aaeFE1dCd85E556d82068675eac6cDC,
        0x1681020FB995c4C26c7Bd9036Bb251Bb1adfb337,
        0x81Be5cce410d13b0B8B65E1154cD1a56Ff4C6ddd,
        0x1B902d0FB8bFABF14593d1BDFb18b00b9f9B08f3,
        0x40aE66344EBc5b00cb2f9aB5c959214BA579642D,
        0xFB7cdD25B7bC07C4A62355D15Ed1097f7A2B45bE,
        0xd75A69A79B949F6022E518c96caf78781ca2FE89,
        0x3cD42f606f5aeB6AD7A4B098594E051a48390708,
        0x67f866DDFF72A960959aC5aD2d077F5a196710c1,
        0xc7F45A866134e1c49377Cff3E25824Cf0603594d,
        0xB955EebA98b48A0C0A97af0302fE05D9E1eB4Bc0,
        0x2dF6e168b4417c162373223A46fC14F6DBBC7838,
        0xa81B4C90bD03496c44882F38Aee70dED4155c7D6,
        0x2A28e74C034710cCce2e7275C6c1d0778D60daed,
        0xbD137384428EFBA9612C8eB95F3413feb327e3De,
        0xc23352C26FE7fA6556E790ED3Ace42eE5582C5F5,
        0xF219A00FEFC86e283103a33B5cd7a9485EE4Dfa1,
        0x93c67F631d2C6b3FFf9B83e5A155184A0aFA63A8,
        0x54dC44ED6107c1dc693619b6dBd20FBB880a1f69,
        0x1680722a1BC609c7A2C3b67Cb3693c00e50bd91A,
        0xe72553aEf9201EEab5c01cC6FDD2595cD39089EA,
        0xB372B7e23942D540910453bDdc50dFCdbc284E96,
        0x055aD5c3871510Bc6dA57cd7B3Be0fe7B8f1Ed38,
        0x4526fc507Dc781DEa33cb96e0e864e1644026bf9,
        0x3D139AE6E4A2287E9aCb8Db276FB4d6f8123E55F,
        0xF9C1238EAdf15afD88828BE5719EC5858b9F67ee,
        0x0d60b347E261abA45dA50e8eED8BCB8cdb59D517,
        0xA9fcdA9E763f6cb38626073AdeECf642F97D7296,
        0xa24aD7a7efADEbBc0b44157572645a8676303E5d,
        0x32cC830Bfd85A07919D6b9c6f36fd29C01FE4a35,
        0xe3090ce96d1Db60146B3fDa603447a2710552Cda,
        0xD0ea0AfDD89CF92c84825f90D0210274c4aC3448,
        0x3aCE72757F247cF9a331d12e4E93f71809AeC1e1,
        0xf84E7085a174aC51fCA22DEA3dCF4A95a7f49b6a,
        0xf5413155eF5fCEfdC93C0a941AD40F6eec0ea044,
        0x6e339365bE3bbD4556d9df0AcA628E6b182056bF,
        0x3FA59B6B3305715523FE5A68E61685AE7FF5a3e3,
        0x44173d7d7cA60719b287d41F4EC4fdad9B042D16,
        0x513A38010930A79A686A8c172835cD244823F05e,
        0x0A933ABB3a022263890992B29E302d9453B4Bae5,
        0x58b48929c4fACA464e7d43cCEa150BAe641C19E7,
        0xd4bee9BEF91ED6C3fEf2643C0E8C1c888F31f8c5,
        0xBA0d97E0377924ca96594C373806994c73fe5591,
        0xA8EeF4658E9d5B033dDB3a19F274D6F2Bf0104E0,
        0x5a35c753f4cBe049B8319642782CF3ef605412BE,
        0x820e77B5d0F56BC740B55c4e1D27eB62937cc113
    ];

    address[] holdersLimited = [
        0x98f4a6325BB290777Db6D876E87BF9664838EB5D,
        0x2764822297a7433B9Ecb51EABC38FFBa3B70A059,
        0xD3f107701fbe154866711FDE4b8A3EDA713E0eb3,
        0xb612878AB836f549fcB42B004416346ab0d83d24,
        0x0e76943A45f3DD02EDBD78067930c1bFa8DA96e1
    ];
    address[] holdersLimited2 = [
        0xD3f107701fbe154866711FDE4b8A3EDA713E0eb3,
        0x98f4a6325BB290777Db6D876E87BF9664838EB5D,
        0xb612878AB836f549fcB42B004416346ab0d83d24,
        0x2764822297a7433B9Ecb51EABC38FFBa3B70A059,
        0x0e76943A45f3DD02EDBD78067930c1bFa8DA96e1
    ];

    uint128[] balances1 = [
        2_290_000 ether,
        549_026 ether,
        500_000 ether,
        250_000 ether,
        247_199.82 ether,
        70_100.86 ether,
        39_664.24 ether,
        34_787.52 ether,
        32_611.70 ether,
        32_368.12 ether,
        30_000 ether,
        25_888.17 ether,
        25_018.44 ether,
        25_000 ether,
        20_009.48 ether,
        20_000 ether,
        20_000 ether,
        20_000 ether,
        20_000 ether,
        20_000 ether,
        20_000 ether,
        20_000 ether,
        20_000 ether,
        20_000 ether,
        20_000 ether,
        20_000 ether,
        20_000 ether,
        20_000 ether,
        20_000 ether,
        20_000 ether,
        20_000 ether,
        18_204.02 ether,
        17_318.84 ether,
        16_517.45 ether,
        15_000 ether,
        14_994.10 ether,
        13_516.96 ether,
        12_500 ether,
        11_653.26 ether,
        11_110 ether,
        10_753.86 ether,
        10_750 ether,
        10_673.49 ether,
        10_000 ether,
        10_000 ether,
        10_000 ether,
        10_000 ether,
        9_999.52 ether,
        9_998.65 ether,
        9_816.34 ether,
        9_645.58 ether,
        9_312.73 ether,
        8_664.35 ether,
        8_156.75 ether,
        8_000 ether,
        7_704.80 ether,
        6_760.83 ether,
        6_658.60 ether,
        6_305.16 ether,
        6_185.39 ether,
        5_989.27 ether,
        5_650 ether,
        5_523.31 ether,
        5_125.61 ether,
        5_110.41 ether,
        5_072.04 ether,
        5_065.86 ether,
        4_858.89 ether,
        4_699.40 ether,
        4_444.44 ether,
        4_444.44 ether,
        4_225.70 ether,
        4_220.84 ether,
        4_142.93 ether,
        3_896.81 ether,
        3_722.71 ether,
        3_705.37 ether,
        3_671.10 ether,
        3_501.13 ether,
        3_181.65 ether,
        3_096.66 ether,
        3_056.99 ether,
        2_948.04 ether,
        2_901.68 ether,
        2_900.67 ether,
        2_745.42 ether,
        2_607.69 ether,
        2_528.08 ether,
        2_338.77 ether,
        2_310.44 ether,
        2_278.23 ether,
        2_270.01 ether,
        2_262.23 ether,
        2_053.62 ether,
        2_000.47 ether,
        1_957.22 ether,
        1_934.56 ether,
        1_823.42 ether,
        1_777.78 ether,
        1_770.85 ether,
        1_659.44 ether,
        1_657.35 ether,
        1_646.73 ether,
        1_413.81 ether,
        1_385.52 ether,
        1_367.31 ether,
        1_352.31 ether,
        1_318.64 ether,
        1_265.34 ether,
        1_262.06 ether,
        1_191.12 ether,
        1_178.61 ether,
        1_167.11 ether,
        1_157.45 ether,
        1_111.96 ether,
        1_089.94 ether,
        1_088.11 ether,
        1_053.37 ether,
        1_052.40 ether,
        1_047.70 ether,
        1_046.94 ether,
        1_041.40 ether,
        1_034.10 ether,
        1_031.68 ether,
        1_029.74 ether,
        1_001.78 ether,
        1_001.21 ether
    ];
    uint128[] balancesLimited = [
        70_000 ether,
        20_000 ether,
        1_000 ether,
        15_000 ether,
        200 ether
    ];
    uint128[] balancesLimited2 = [
        1_000 ether,
        70_000 ether,
        15_000 ether,
        20_000 ether,
        200 ether
    ];

    function setUp() public {
        lynx = new Lynx(owner, owner);
        profitSharing = new LynxManualProfitDistribution(address(lynx), owner);

        vm.deal(owner, 100 ether);

        vm.startPrank(owner);
        lynx.setMaxWallet(5_000_000 ether);
        lynx.setSnapshotterAddress(address(profitSharing), true);
        vm.stopPrank();
    }

    modifier lynxLargeDump() {
        vm.startPrank(owner);
        for (uint i = 0; i < holders.length; i++) {
            lynx.transfer(holders[i], balances1[i]);
        }
        vm.stopPrank();
        _;
    }
    modifier limitedDump() {
        vm.startPrank(owner);
        for (uint i = 0; i < holdersLimited.length; i++) {
            lynx.transfer(holdersLimited[i], balancesLimited[i]);
        }
        vm.stopPrank();
        _;
    }

    function test_add_rewards() public lynxLargeDump {
        uint128 adjustment = 2_290_000 ether;
        vm.prank(owner);
        profitSharing.createSnapshot{value: 1 ether}(
            holders,
            balances1,
            adjustment,
            0
        );

        (uint t1, uint t2, ) = lynx.snapshots(0);

        (uint128 tt1, uint128 tt2, , , , , ) = profitSharing.snapshots(0);
        assertEq(tt1, t1 - adjustment);
        assertEq(tt2, t2);
        assertEq(address(profitSharing).balance, 1 ether);
    }

    function test_claimRewards() public limitedDump {
        vm.prank(owner);
        profitSharing.createSnapshot{value: 1 ether}(
            holdersLimited,
            balancesLimited,
            0,
            0
        );

        uint[] memory ids = new uint[](1);
        uint[] memory qualifyingIndex = new uint[](1);
        uint[] memory verificationIndex = new uint[](1);

        ids[0] = 0;
        qualifyingIndex[0] = 0;
        verificationIndex[0] = 0;

        vm.prank(holdersLimited[0]);
        vm.expectRevert();
        profitSharing.claimDivs(ids, qualifyingIndex, verificationIndex);

        vm.prank(owner);
        profitSharing.createSnapshot{value: 1 ether}(
            holdersLimited2,
            balancesLimited2,
            0,
            0
        );

        uint h1Balance = holdersLimited[0].balance;

        vm.startPrank(holdersLimited[0]);
        //Should Fail because of wrong verification index
        vm.expectRevert(LynxPS__InvalidClaimer.selector);
        profitSharing.claimDivs(ids, qualifyingIndex, verificationIndex);

        //Should Fail because of wrong qualifyingIndex index
        qualifyingIndex[0] = 1;
        vm.expectRevert(LynxPS__InvalidClaimer.selector);
        profitSharing.claimDivs(ids, qualifyingIndex, verificationIndex);

        // Should Succeed
        qualifyingIndex[0] = 0;
        verificationIndex[0] = 1;
        profitSharing.claimDivs(ids, qualifyingIndex, verificationIndex);

        // Should Fail because already claimed
        vm.expectRevert(LynxPS__AlreadyClaimedOrInvalidSnapshotClaim.selector);
        profitSharing.claimDivs(ids, qualifyingIndex, verificationIndex);

        vm.stopPrank();
        uint expectedReward = 0.6 ether;
        uint diffBalance = holdersLimited[0].balance - h1Balance;
        if (diffBalance < expectedReward)
            assertLt(expectedReward - diffBalance, 1 gwei);
        else assertLt(diffBalance - expectedReward, 1 gwei);
    }

    function test_reclaimRewards() public limitedDump {
        vm.startPrank(owner);
        profitSharing.createSnapshot{value: 1 ether}(
            holdersLimited,
            balancesLimited,
            0,
            0
        );

        skip(5 days);

        vm.expectRevert(LynxPS__InvalidReclaim.selector);
        profitSharing.removeUnclaimedRewards(0);

        profitSharing.createSnapshot{value: 1 ether}(
            holdersLimited,
            balancesLimited,
            0,
            0
        );
        skip(25 days);
        profitSharing.removeUnclaimedRewards(0);

        assertLt(address(profitSharing).balance, 1.0000001 ether);

        vm.stopPrank();

        uint[] memory ids = new uint[](1);
        uint[] memory qualifyingIndex = new uint[](1);
        uint[] memory verificationIndex = new uint[](1);

        ids[0] = 0;
        qualifyingIndex[0] = 0;
        verificationIndex[0] = 0;
        vm.prank(holdersLimited[0]);
        vm.expectRevert(LynxPS__AlreadyClaimedOrInvalidSnapshotClaim.selector);
        profitSharing.claimDivs(ids, qualifyingIndex, verificationIndex);
    }

    function test_excluded_no_claim() public limitedDump {
        uint[] memory ids = new uint[](1);
        uint[] memory qualifyingIndex = new uint[](1);
        uint[] memory verificationIndex = new uint[](1);
        ids[0] = 0;
        qualifyingIndex[0] = 0;
        verificationIndex[0] = 0;

        vm.prank(address(0));
        vm.expectRevert(LynxPS__ExcludedClaimer.selector);
        profitSharing.claimDivs(ids, qualifyingIndex, verificationIndex);

        vm.prank(owner);
        vm.expectRevert(LynxPS__ExcludedClaimer.selector);
        profitSharing.excludeUser(address(0));
    }
}
