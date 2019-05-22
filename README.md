# BLS signature verification

**Warning: This is toy POC and an academic review is required.**

Validate multiple signatures on Ethereum chain using BLS.

### Rogue key attack

Proofs-of-possession(POP) at registration to address the rogue public key attack [see here](https://eprint.iacr.org/2007/264.pdf)

- This code does not check for POP.
- We can test POP at validator/user registration time. We can get any data signed and verify using pubkey. However, we will add this later.

## Curve points

- We are currently using [py_ecc](https://github.com/ethereum/py_ecc) [py_ecc/fork](https://github.com/0xAshish/py_ecc) for testing/poc purpose
- In the future we will use rust [code](https://github.com/zkcrypto/pairing) for faster results

[BN256G2]() is used for solidity G2 point operations and pre-compiles ECMUL, ECADD and ECPARING

- Test data/points generated using [BLSSmall.py](https://github.com/0xAshish/py_ecc/blob/master/tests/BLSsmall.py)

### G1 points

Generator for curve over FQ

```
G1 = (FQ(1), FQ(2))
```

### G2 points

Generator for twisted curve over FQ2

```
G2 = (
    FQ2([11559732032986387107991004021392285783925812861821192530917403151452391805634,
        10857046999023057135944570762232829481370756359578518086990519993285655852781]),
    FQ2([4082367875863433681332203403145435568316851327593401208105741076214120093531,
        8495653923123431417604973247489272438418190587263600148770280649306958101930]))
)
```

### Private key `sk`

Securely generated number

### Public keys `pk`

Public keys are G1 points on the curve.
`pk = mul(G1, sk)`

### `hashToG2`

- Message m = data to be signed
- h = Hash of Message m or some numeric deterministic representation
- H is Point on G2
- Currently, for toy version we are using `hashToG2` => `mul(G2, h)`
- Some better methods for `hashToG1/G2` [`try-and-increment`, [hashingToBNCurves](https://www.di.ens.fr/~fouque/pub/latincrypt12.pdf)] can be used for real use cases.

### BLS signing `sig`

- sig is a valid G2 point
- `sig = mul(H, sk)`

## Aggregation operations

### `aggregate pubkeys`

```
aggPubkey
for each pubkey in pubkeys:
  aggPubkey = add(aggPubkey, pubkey)

```

where `add` is the elliptic curve addition operation over the G1 curve and the empty aggSigs is the G1 point at infinity.

### `Aggregate signatures`

```
aggSigs
for each sig in sigs:
  aggSigs = add(aggSig, sig)

```

where `add` is the elliptic curve addition operation over the G2 curve and the empty aggSigs is the G2 point at infinity.

## Signature verification

In the following, `e` is the pairing function with the following coordinates (see [here](https://github.com/zkcrypto/pairing/tree/master/src/bls12_381#g1)):

### `BLS Sig verify`

aggPubkey = `aggregated pubkeys`
aggSig is aggregation of n sigs from n privkeys/validators

- Each `pubkey` in `pubkeys` is a valid G1 point.
- `signature` is a valid G2 point.
- Verify pairing `e(add(pubkeys[0]...[n]), hashtoG2(message)) == e(G1, aggSig)`.

where `add` is the elliptic curve addition operation over the G1 curve and the empty aggSigs is the G1 point at infinity.

### Try-and-increment

```
def hash_to_G2(message_hash: Bytes32, domain: uint64) -> [uint384]:
    # Initial candidate x coordinate
    x_re = int.from_bytes(hash(message_hash + bytes8(domain) + b'\x01'), 'big')
    x_im = int.from_bytes(hash(message_hash + bytes8(domain) + b'\x02'), 'big')
    x_coordinate = Fq2([x_re, x_im])  # x = x_re + i * x_im

    # Test candidate y coordinates until a one is found
    while 1:
        y_coordinate_squared = x_coordinate ** 3 + Fq2([4, 4])  # The curve is y^2 = x^3 + 4(i + 1)
        y_coordinate = modular_squareroot(y_coordinate_squared)
        if y_coordinate is not None:  # Check if quadratic residue found
            return multiply_in_G2((x_coordinate, y_coordinate), G2_cofactor)
        x_coordinate += Fq2([1, 0])  # Add 1 and try again
```

Above algorithm from [ETH2.0](https://github.com/ethereum/eth2.0-specs/blob/dev/specs/bls_signature.md#hash_to_g2) can be used for `hashToG2`.

#### References

1. https://www.di.ens.fr/~fouque/pub/latincrypt12.pdf
2. https://crypto.stanford.edu/~dabo/pubs/papers/BLSmultisig.html
3. https://crypto.stanford.edu/pbc/thesis.pdf
4. http://www.craigcostello.com.au/pairings/PairingsForBeginners.pdf
5. https://eprint.iacr.org/2007/264.pdf
