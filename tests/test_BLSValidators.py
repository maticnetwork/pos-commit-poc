import unittest
from ethereum.tools import tester
from binascii import hexlify

import bls


class TestBLSValidators(unittest.TestCase):
    def setUp(self):
        env = tester.get_env(None)
        env.config['BLOCK_GAS_LIMIT'] = 5**10
        chain = tester.Chain(env=env) 

        with open('BN256G2.sol') as handle:
            source = handle.read()
            BN256G2 = chain.contract(source, language='solidity')
        with open('BLSValidators.sol') as handle:
            source = handle.read()
            self.contract = chain.contract(source, libraries={'BN256G2': hexlify(BN256G2.address)}, language='solidity')

    def test_AddValidator(self):
        index = 0
        sk, pk = bls.bls_keygen()
        sig = bls.bls_prove_key(sk)
        result = self.contract.AddValidator(0, bls.g2_to_list(pk), bls.g1_to_list(sig), value=1000)
        print(result)
        result2 = self.contract.GetValidator(0)
        print(result2)


if __name__ == '__main__':
    unittest.main()
