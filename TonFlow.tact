import "@stdlib/deploy";

// ─── Messages ─────────────────────────────────────────────────────────────────

message(0x10) CreateDCA {
    tokenIn:    Address;   // token to spend
    tokenOut:   Address;   // token to receive
    amountIn:   Int as coins; // amount per execution
    interval:   Int as uint32; // seconds between executions (e.g. 86400 = daily)
    executions: Int as uint32; // total number of executions
}

message(0x11) CancelDCA {
    orderId: Int as uint64;
}

message(0x12) ExecuteDCA {
    orderId: Int as uint64;
}

message(0x20) CreateLimitOrder {
    tokenIn:    Address;
    tokenOut:   Address;
    amountIn:   Int as coins;
    targetPrice: Int as uint256; // price in tokenOut per tokenIn, scaled 1e9
}

message(0x21) CancelLimitOrder {
    orderId: Int as uint64;
}

message(0x22) ExecuteLimitOrder {
    orderId:      Int as uint64;
    currentPrice: Int as uint256; // provided by keeper, verified on-chain
}

// ─── Structs ──────────────────────────────────────────────────────────────────

struct DCAOrder {
    owner:      Address;
    tokenIn:    Address;
    tokenOut:   Address;
    amountIn:   Int as coins;
    interval:   Int as uint32;
    executions: Int as uint32;
    executed:   Int as uint32;
    lastExec:   Int as uint64;
    active:     Bool;
}

struct LimitOrder {
    owner:       Address;
    tokenIn:     Address;
    tokenOut:    Address;
    amountIn:    Int as coins;
    targetPrice: Int as uint256;
    active:      Bool;
}

// ─── Contract ─────────────────────────────────────────────────────────────────

contract TonFlow with Deployable {

    owner:        Address;
    nextOrderId:  Int as uint64 = 0;

    dcaOrders:    map<Int, DCAOrder>;
    limitOrders:  map<Int, LimitOrder>;

    // Referral address for STON.fi SDK fee routing
    referrer:     Address;

    init(referrer: Address) {
        self.owner    = sender();
        self.referrer = referrer;
    }

    // ─── DCA ─────────────────────────────────────────────────────────────────

    receive(msg: CreateDCA) {
        require(msg.executions > 0, "Must have at least 1 execution");
        require(msg.interval >= 3600, "Minimum interval 1 hour");

        let id: Int = self.nextOrderId;
        self.nextOrderId = self.nextOrderId + 1;

        self.dcaOrders.set(id, DCAOrder{
            owner:      sender(),
            tokenIn:    msg.tokenIn,
            tokenOut:   msg.tokenOut,
            amountIn:   msg.amountIn,
            interval:   msg.interval,
            executions: msg.executions,
            executed:   0,
            lastExec:   0,
            active:     true
        });
    }

    receive(msg: CancelDCA) {
        let order: DCAOrder? = self.dcaOrders.get(msg.orderId);
        require(order != null, "Order not found");
        require(order!!.owner == sender(), "Not owner");
        require(order!!.active, "Already inactive");

        self.dcaOrders.set(msg.orderId, DCAOrder{
            owner:      order!!.owner,
            tokenIn:    order!!.tokenIn,
            tokenOut:   order!!.tokenOut,
            amountIn:   order!!.amountIn,
            interval:   order!!.interval,
            executions: order!!.executions,
            executed:   order!!.executed,
            lastExec:   order!!.lastExec,
            active:     false
        });
    }

    receive(msg: ExecuteDCA) {
        // Called by keeper bot when interval has passed
        let order: DCAOrder? = self.dcaOrders.get(msg.orderId);
        require(order != null, "Order not found");
        require(order!!.active, "Order inactive");
        require(order!!.executed < order!!.executions, "All executions done");
        require(
            now() >= order!!.lastExec + order!!.interval,
            "Interval not reached"
        );

        // TODO M2: call STON.fi SDK swap here with self.referrer for referral fee
        // stonfi.swap(order.tokenIn, order.tokenOut, order.amountIn, self.referrer)

        let isDone: Bool = order!!.executed + 1 >= order!!.executions;
        self.dcaOrders.set(msg.orderId, DCAOrder{
            owner:      order!!.owner,
            tokenIn:    order!!.tokenIn,
            tokenOut:   order!!.tokenOut,
            amountIn:   order!!.amountIn,
            interval:   order!!.interval,
            executions: order!!.executions,
            executed:   order!!.executed + 1,
            lastExec:   now(),
            active:     !isDone
        });
    }

    // ─── Limit Orders ─────────────────────────────────────────────────────────

    receive(msg: CreateLimitOrder) {
        require(msg.amountIn > 0, "Amount must be > 0");
        require(msg.targetPrice > 0, "Target price must be > 0");

        let id: Int = self.nextOrderId;
        self.nextOrderId = self.nextOrderId + 1;

        self.limitOrders.set(id, LimitOrder{
            owner:       sender(),
            tokenIn:     msg.tokenIn,
            tokenOut:    msg.tokenOut,
            amountIn:    msg.amountIn,
            targetPrice: msg.targetPrice,
            active:      true
        });
    }

    receive(msg: CancelLimitOrder) {
        let order: LimitOrder? = self.limitOrders.get(msg.orderId);
        require(order != null, "Order not found");
        require(order!!.owner == sender(), "Not owner");
        require(order!!.active, "Already inactive");

        self.limitOrders.set(msg.orderId, LimitOrder{
            owner:       order!!.owner,
            tokenIn:     order!!.tokenIn,
            tokenOut:    order!!.tokenOut,
            amountIn:    order!!.amountIn,
            targetPrice: order!!.targetPrice,
            active:      false
        });
    }

    receive(msg: ExecuteLimitOrder) {
        // Called by keeper bot when price condition is met
        let order: LimitOrder? = self.limitOrders.get(msg.orderId);
        require(order != null, "Order not found");
        require(order!!.active, "Order inactive");
        require(msg.currentPrice >= order!!.targetPrice, "Price not reached");

        // TODO M2: call STON.fi SDK swap here with self.referrer for referral fee
        // stonfi.swap(order.tokenIn, order.tokenOut, order.amountIn, self.referrer)

        self.limitOrders.set(msg.orderId, LimitOrder{
            owner:       order!!.owner,
            tokenIn:     order!!.tokenIn,
            tokenOut:    order!!.tokenOut,
            amountIn:    order!!.amountIn,
            targetPrice: order!!.targetPrice,
            active:      false
        });
    }

    // ─── Getters ──────────────────────────────────────────────────────────────

    get fun getDCAOrder(id: Int): DCAOrder? {
        return self.dcaOrders.get(id);
    }

    get fun getLimitOrder(id: Int): LimitOrder? {
        return self.limitOrders.get(id);
    }

    get fun totalOrders(): Int {
        return self.nextOrderId;
    }

    get fun referrerAddress(): Address {
        return self.referrer;
    }
}
