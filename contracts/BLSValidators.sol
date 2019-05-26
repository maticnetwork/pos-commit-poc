pragma solidity ^0.5.8;
pragma experimental ABIEncoderV2;


import { BN256G2 } from "./BN256G2.sol";


contract BLSValidators
{
    uint256 internal constant FIELD_ORDER = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47;

    // a = (p+1) / 4
    uint256 internal constant CURVE_A = 0xc19139cb84c680a6e14116da060561765e05aa45a1c72a34f082305b61f3f52;


    struct G1Point {
        uint X;
        uint Y;
    }

    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint256[2] X;
        uint256[2] Y;
    }

    struct Validator {
        address owner;
        uint256 amount;
        G2Point pubkey;
    }

    uint256 internal aggregate_bitmask;
    G2Point internal aggregate_pubkey;

    mapping (uint8 => Validator) internal validators;

    event OnNewValidator(uint8 index, address owner, G2Point pk);

    event OnValidatorRemoved(uint8 index);

    constructor () public {
        aggregate_pubkey = G2Point([uint256(0), uint256(0)], [uint256(0), uint256(0)]);
    }

    function HashToG1(uint256 s)
        public view returns (G1Point memory)
    {
        uint256 beta = 0;
        uint256 y = 0;
        uint256 x = s % FIELD_ORDER;
        while( true ) {
            (beta, y) = FindYforX(x);
            if(beta == mulmod(y, y, FIELD_ORDER)) {
                return G1Point(x, y);
            }
            x = addmod(x, 1, FIELD_ORDER);
        }
    }

    function FindYforX(uint256 x)
        internal view returns (uint256, uint256)
    {
        // beta = (x^3 + b) % p
        uint256 beta = addmod(mulmod(mulmod(x, x, FIELD_ORDER), x, FIELD_ORDER), 3, FIELD_ORDER);
        uint256 y = modPow(beta, CURVE_A, FIELD_ORDER);
        return (beta, y);
    }

    function AddValidator(uint8 index, G2Point memory pk)
        public payable
    {
        require( msg.value != 0 );        
        require( validators[index].owner == address(0) );
        
        // TODO: validate ownership of public key

        validators[index] = Validator(msg.sender, msg.value, pk);

        // To handle the special case where all validators agree on something
        // We pre-accumulate the keys to avoid doing it every time a signature is validated
        // Maintain a bitmask of their indices 
        G2Point memory p;
        (p.X[0], p.X[1], p.Y[0], p.Y[1]) = BN256G2.ECTwistAdd(aggregate_pubkey.X[0], aggregate_pubkey.X[1],
                                                              aggregate_pubkey.Y[0], aggregate_pubkey.Y[1],
                                                              pk.X[0], pk.X[1], pk.Y[0], pk.Y[1]);
        aggregate_pubkey = p;
        aggregate_bitmask = aggregate_bitmask & (uint256(1)<<index);

        emit OnNewValidator(index, msg.sender, pk);
    }

    function RemoveValidator(uint8 index)
        public
    {
        Validator storage who = validators[index];
        require( who.owner == msg.sender );        

        // Remove their key from the aggregate, and their index from the bitmask
        G2Point memory p = negate(who.pubkey);
        (p.X[0], p.X[1], p.Y[0], p.Y[1]) = BN256G2.ECTwistAdd(aggregate_pubkey.X[0], aggregate_pubkey.X[1],
                                                              aggregate_pubkey.Y[0], aggregate_pubkey.Y[1],
                                                              p.X[0], p.X[1], p.Y[0], p.Y[1]);
        aggregate_pubkey = p;
        aggregate_bitmask = aggregate_bitmask ^ (uint256(1)<<index);

        // Save amount before deleting
        // must be deleted first, otherwise opens up re-entrancy bugs
        uint256 amount = who.amount;
        delete validators[index];

        // Return their deposit
        msg.sender.transfer(amount);

        emit OnValidatorRemoved(index);
    }

    function GetValidator(uint8 index)
        public view
        returns(address, uint256, uint256[2] memory, uint256[2] memory)
    {
        Validator memory who = validators[index];
        return (who.owner, who.amount, who.pubkey.X, who.pubkey.Y);
    }
    
    function CheckSignature(uint256 message, G2Point memory pubkey, G1Point memory sig)
        public view returns (bool)
    {
        G1Point memory H = HashToG1(message);
        // Note: for the pairing product to evaluate to 1, we need to negate signature
        // XXX: this should probaby be done on the client-side
        return pairing2(H, pubkey, negate(sig), G2());
    }

    function CheckSignature(uint256 bitmask, uint256 sigX, uint256 sigY, uint256 message)
        public view returns(bool)
    {
        G2Point memory ap;
        // In the special case where all aggregators agree on the same signature
        if( bitmask == aggregate_bitmask ) {
            ap = aggregate_pubkey;
        }
        else {
            for(uint8 i = 0; i < 0xFF; i++) {
                if( (bitmask >> i) & 1 > 0 ) {
                    require( validators[i].owner != address(0) );
                    G2Point memory p = validators[i].pubkey;
                    (ap.X[0], ap.X[1], ap.Y[0], ap.Y[1]) = BN256G2.ECTwistAdd(ap.X[0], ap.X[1],
                                                                              ap.Y[0], ap.Y[1],
                                                                              p.X[0], p.X[1],
                                                                              p.Y[0], p.Y[1]);
                }
            }
        }
        G1Point memory H = HashToG1(message);
        return pairing2(H, G2(), G1Point(sigX, sigY), ap);
    }

    /// @return the generator of G1
    function G1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }

    /// @return the generator of G2
    function G2() internal pure returns (G2Point memory) {
        return G2Point(
            [0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2,
             0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed],
            [0x90689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b,
             0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa]
        );
    }

    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2)
        internal view returns (bool)
    {
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
            success := staticcall(sub(gas, 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
        }
        require(success);
        return out[0] != 0;
    }

    /// Convenience method for a pairing check for two pairs.
    function pairing2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2)
        internal view returns (bool)
    {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }

    function modPow(uint256 base, uint256 exponent, uint256 modulus)
        internal view returns (uint256)
    {
        uint256[6] memory input = [32, 32, 32, base, exponent, modulus];
        uint256[1] memory result;
        assembly {
            if iszero(staticcall(not(0), 0x05, input, 0xc0, result, 0x20)) {
                revert(0, 0)
            }
        }
        return result[0];
    }

    function negate(uint256 value)
        internal pure returns (uint256)
    {
        return FIELD_ORDER - (value % FIELD_ORDER);
    }

    function negate(uint256[2] memory value)
        internal pure returns (uint256[2] memory)
    {
        return [FIELD_ORDER - (value[0] % FIELD_ORDER),
                FIELD_ORDER - (value[1] % FIELD_ORDER)];
    }

    /// @return the negation of p, i.e. p.add(p.negate()) should be zero.
    function negate(G1Point memory p)
        internal pure returns (G1Point memory)
    {
        // The prime q in the base field F_q for G1
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, negate(p.Y));
    }

    function negate(G2Point memory p)
        internal pure returns (G2Point memory)
    {
        return G2Point(p.X, negate(p.Y));
    }

    /// @return the sum of two points of G1
    function PointAdd(G1Point memory p1, G1Point memory p2) internal returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        assembly {
            success := call(sub(gas, 2000), 6, 0, input, 0xc0, r, 0x60)
        }
        require(success);
    }

    /// @return the product of a point on G1 and a scalar, i.e.
    /// p == p.mul(1) and p.add(p) == p.mul(2) for all points p.
    function PointMul(G1Point memory p, uint s) internal returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        assembly {
            success := call(sub(gas, 2000), 7, 0, input, 0x80, r, 0x60)
        }
        require(success);
    }
}
