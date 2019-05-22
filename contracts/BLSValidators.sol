pragma solidity ^0.4.24;

import { BN256G2 } from "./BN256G2.sol";

/*
Toy working POC on BLS Sig and aggregation in Ethereum.

Signatures are generated using https://github.com/0xAshish/py_ecc/blob/master/tests/BLSsmall.py

Code is based on https://github.com/jstoxrocky/zksnarks_example

*/

contract BLSValidators {

    struct G1Point {
        uint X;
        uint Y;
    }

    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }

    struct Validator {
        address user;
        uint256 amount;
        G1Point pubkey;
    }

    uint256 public vCount = 0;
    mapping (uint256 => Validator) public validators;

    event newValidator(uint256 indexed validatorId);

    function addValidator(uint256 pkX, uint256 pkY, uint256 amount) public {
         vCount++;
         validators[vCount] = Validator(msg.sender, amount, G1Point(pkX, pkY));
         emit newValidator(vCount);
    }

    function addValidatorTest(uint256 amount, uint256 _pk,uint256 n) public {
        for(uint256 i = 0 ;i < n; i++) {
         vCount++;
         // Temporary
         G1Point memory pk = mul(P1(), _pk+i);
         validators[vCount] = Validator(msg.sender,amount, pk);
        }
    }

    function getValidatorDetails(uint256 id) public view
     returns(
        address,
        uint256,
        uint256,
        uint256
        ) {
        return (validators[id].user, validators[id].amount, validators[id].pubkey.X, validators[id].pubkey.Y);
    }

    function checkSigAGG(uint256 bitmask, uint256 sigs0, uint256 sigs1, uint256 sigs2, uint256 sigs3, uint256 message) public returns(bool) {
        G1Point memory pubkey;
        for(uint256 i = 0; i < vCount; i++) {
            // if((bitmask >> i) & 1 > 0) {
                Validator v = validators[i+1];
                pubkey = add(pubkey, v.pubkey);
            // }
        }

        G2Point memory H = hashToG2(12312312345);
        G2Point memory signature = G2Point([sigs1,sigs0],[sigs3,sigs2]);
        return pairing2(P1(), H, negate(pubkey), signature);
    }


    function testCheckSigAGG() public {
        G1Point memory pubkey = G1Point(
        17380323886581056473092238415087178747833394266216426706118377188344506669132,
        8264330258127714892906603723635360533223500611780692134587255146148491007336);

        G2Point memory H = G2Point(
        [7806540115951598708068323537226325143489341620121102987168061034219723055482,
        16102053849180588443131133900438094849149715436625045469236991987039241848240],
        [6718946360417026759307173704450430250787528919693688413464546568151449945362,
         15085587210032391178752839157819905008772577581989468040951987143794090031385]);

        G2Point memory signature = G2Point(
        [20510297253563043906240734487189027213933976667621835319448331165769997484335,
         17039283792713629953217756598150981109636679343767085841835508695942368202923],
        [1985362097212581787757922254110217851026070065076532109495179805548055991837,
         7135647869386222135872517926452623520408611489591663660104271578165118400268]);

        require(pairing2(P1(), H, negate(pubkey), signature), "Something went wrong");
    }

    /// @return the generator of G1
    function P1() internal returns (G1Point) {
        return G1Point(1, 2);
    }

    /// @return the generator of G2
    function P2() internal returns (G2Point) {
        return G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
            10857046999023057135944570762232829481370756359578518086990519993285655852781],

            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
            8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
    }

    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal returns (bool) {
        require(p1.length == p2.length);
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);

        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }

        uint[1] memory out;
        bool success;

        assembly {
            success := call(sub(gas, 2000), 8, 0, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
        // Use "invalid" to make gas estimation work
            switch success case 0 {invalid}
        }
        require(success);
        return out[0] != 0;
    }

    /// Convenience method for a pairing check for two pairs.
    function pairing2(G1Point a1, G2Point a2, G1Point b1, G2Point b2) internal returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }

    function hashToG1(uint256 h) internal returns (G1Point) {
        return mul(P1(), h);
    }

    function hashToG2(uint256 h) internal returns (G2Point memory) {
        G2Point memory p2 = P2();
        uint256 x1;
        uint256 x2;
        uint256 y1;
        uint256 y2;
        (x1,x2,y1,y2) = BN256G2.ECTwistMul(h, p2.X[1], p2.X[0], p2.Y[1], p2.Y[0]);
        return G2Point([x2,x1],[y2,y1]);
    }

    function modPow(uint256 base, uint256 exponent, uint256 modulus) internal returns (uint256) {
        uint256[6] memory input = [32, 32, 32, base, exponent, modulus];
        uint256[1] memory result;
        assembly {
            if iszero(call(not(0), 0x05, 0, input, 0xc0, result, 0x20)) {
                revert(0, 0)
            }
        }
        return result[0];
    }

    /// @return the negation of p, i.e. p.add(p.negate()) should be zero.
    function negate(G1Point p) internal returns (G1Point) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }

    /// @return the sum of two points of G1
    function add(G1Point p1, G1Point p2) internal returns (G1Point r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        assembly {
            success := call(sub(gas, 2000), 6, 0, input, 0xc0, r, 0x60)
        // Use "invalid" to make gas estimation work
            switch success case 0 {invalid}
        }
        require(success);
    }

    /// @return the product of a point on G1 and a scalar, i.e.
    /// p == p.mul(1) and p.add(p) == p.mul(2) for all points p.
    function mul(G1Point p, uint s) internal returns (G1Point r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        assembly {
            success := call(sub(gas, 2000), 7, 0, input, 0x80, r, 0x60)
        // Use "invalid" to make gas estimation work
            switch success case 0 {invalid}
        }
        require(success);
    }
}
