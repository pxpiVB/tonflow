import {
    Address,
    beginCell,
    Cell,
    Contract,
    contractAddress,
    ContractProvider,
    Sender,
    SendMode,
    toNano,
} from '@ton/core';

export type TonFlowConfig = {
    referrer: Address;
};

export function tonFlowConfigToCell(config: TonFlowConfig): Cell {
    return beginCell()
        .storeAddress(config.referrer)
        .storeUint(0, 64) // nextOrderId = 0
        .endCell();
}

export class TonFlow implements Contract {
    constructor(
        readonly address: Address,
        readonly init?: { code: Cell; data: Cell }
    ) {}

    static createFromConfig(config: TonFlowConfig, code: Cell, workchain = 0) {
        const data = tonFlowConfigToCell(config);
        const init = { code, data };
        return new TonFlow(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell(),
        });
    }

    async getTotalOrders(provider: ContractProvider): Promise<bigint> {
        const result = await provider.get('totalOrders', []);
        return result.stack.readBigNumber();
    }

    async getReferrerAddress(provider: ContractProvider): Promise<Address> {
        const result = await provider.get('referrerAddress', []);
        return result.stack.readAddress();
    }
}
