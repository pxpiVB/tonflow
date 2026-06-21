import { toNano, Address } from '@ton/core';
import { TonFlow } from '../wrappers/TonFlow';
import { compile, NetworkProvider } from '@ton/blueprint';

// STON.fi referrer address — set to your own wallet to collect referral fees
// Replace with your actual TON wallet address before mainnet deploy
const REFERRER_ADDRESS = Address.parse('0QAtfJwM63DUqH2sWE6US_aMTSXsqV-iOwzGA6Rs9A2HFj6J');

export async function run(provider: NetworkProvider) {
    const tonflow = provider.open(
        TonFlow.createFromConfig(
            { referrer: REFERRER_ADDRESS },
            await compile('TonFlow')
        )
    );

    await tonflow.sendDeploy(provider.sender(), toNano('0.05'));
    await provider.waitForDeploy(tonflow.address);

    console.log('✅ TonFlow deployed at:', tonflow.address.toString());
    console.log('🔗 Testnet explorer:', `https://testnet.tonscan.org/address/${tonflow.address.toString()}`);
}
