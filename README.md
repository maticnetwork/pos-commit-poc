# BLS signature verification

**Warning: This is toy poc and academic review is needed.**

## Curve parameters

currently using [py_ecc](https://github.com/ethereum/py_ecc) [py_ecc/fork](https://github.com/0xAshish/py_ecc) for testing/poc purpose
plan to use rust [code](https://github.com/zkcrypto/pairing) for faser results.
The BLS12-381 curve parameters are defined [here](https://z.cash/blog/new-snark-curve).

### G1 points

Generator for curve over FQ

```
G1 = (FQ(1), FQ(2))
```

### G2 points

Generator for twisted curve over FQ2

```
G2 = (
    FQ2([
        10857046999023057135944570762232829481370756359578518086990519993285655852781,
        11559732032986387107991004021392285783925812861821192530917403151452391805634,
    ]),
    FQ2([
        8495653923123431417604973247489272438418190587263600148770280649306958101930,
        4082367875863433681332203403145435568316851327593401208105741076214120093531,
    ]),
)
```

### private key `sk`

securely generated number

#### public keys `pk`

public keys are G1 points on the curve.
`pk = mul(G1, sk)`

### `hashToG2`

- Message m = some crap data
- h = Hash of Message m or some numeric deterministic repsrentaion
- H is Point on G2
- currently for toy version using straight => `mul(G2, h)`
  to verify/compule `mul(G2, h)` in solidity we are using [BN256G2](https://github.com/musalbas/solidity-BN256G2) thanks mustafa
  > next use something better for hash to G2 [1](https://www.di.ens.fr/~fouque/pub/latincrypt12.pdf)

### signing `sig`

- sign is a G2 point
- mul(G2,x) multiply on G2 point
  `sig = mul(H, sk)`

## Aggregation operations

### `aggregate pubkeys`

```
aggPubkey
for each pubkey in pubkeys:
  aggPubkey = add(aggPubkey, pubkey)

```

where `add` is the elliptic curve addition operation over the G1 curve and the empty aggSigs is the G1 point at infinity.

### `aggregate signatures`

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

refrences

1. https://www.di.ens.fr/~fouque/pub/latincrypt12.pdf
2. https://crypto.stanford.edu/~dabo/pubs/papers/BLSmultisig.html
3. https://crypto.stanford.edu/pbc/thesis.pdf
4. http://www.craigcostello.com.au/pairings/PairingsForBeginners.pdf
