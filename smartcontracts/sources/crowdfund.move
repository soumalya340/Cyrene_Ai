module crowdfund::simple_fund {
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::event;

    /// Errors
    const EAmountTooSmall: u64 = 0;
    const EInsufficientBalance: u64 = 1;
    const EInvalidContribution: u64 = 2;

    /// Structs
    public struct CrowdFund has key {
        id: UID,
        balance: Balance<SUI>,
        min_deposit: u64
    }

    /// Receipt for tracking user's contribution
    public struct Contribution has key {
        id: UID,
        amount: u64,
        contributor: address
    }

    /// Events
    public struct DepositEvent has copy, drop {
        contributor: address,
        amount: u64
    }

    public struct WithdrawEvent has copy, drop {
        contributor: address,
        amount: u64
    }

    /// Create a new crowdfunding pool
    public fun create_fund(min_deposit: u64, ctx: &mut TxContext) {
        let fund = CrowdFund {
            id: object::new(ctx),
            balance: balance::zero(),
            min_deposit
        };
        transfer::share_object(fund);
    }

    /// Deposit SUI into the fund
    public fun deposit(
        fund: &mut CrowdFund, 
        payment: &mut Coin<SUI>, 
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Verify minimum deposit
        assert!(amount >= fund.min_deposit, EAmountTooSmall);
        assert!(coin::value(payment) >= amount, EInsufficientBalance);

        // Split the payment from user's coin
        let coin_balance = coin::balance_mut(payment);
        let paid = balance::split(coin_balance, amount);

        // Add to fund's balance
        balance::join(&mut fund.balance, paid);

        // Create contribution receipt
        let contribution = Contribution {
            id: object::new(ctx),
            amount,
            contributor: tx_context::sender(ctx)
        };

        // Emit deposit event
        event::emit(DepositEvent {
            contributor: tx_context::sender(ctx),
            amount
        });

        // Transfer contribution receipt to contributor
        transfer::transfer(contribution, tx_context::sender(ctx));
    }

    /// Withdraw contributed amount
    public fun withdraw(
        fund: &mut CrowdFund,
        contribution: Contribution,
        ctx: &mut TxContext
    ) {
        let Contribution { id, amount, contributor } = contribution;
        // Verify withdrawal request is from contributor
        assert!(contributor == tx_context::sender(ctx), EInvalidContribution);

        // Split the withdrawal amount from fund's balance
        let withdrawal = balance::split(&mut fund.balance, amount);

        // Emit withdraw event
        event::emit(WithdrawEvent {
            contributor: tx_context::sender(ctx),
            amount
        });

        // Delete contribution receipt
        object::delete(id);

        // Transfer SUI to contributor
        transfer::public_transfer(
            coin::from_balance(withdrawal, ctx),
            contributor
        );
    }

    
}