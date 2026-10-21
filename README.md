# M-Pesa 50/50 split API

This is a Ruby on Rails API for recording Safaricom Paybill C2B payments, allocating each payment 50/50, and tracking a separate B2C payment for the recipient's share. The incoming Paybill transaction itself is not split by Safaricom. Production B2C transfers stay disabled until the account and funding arrangement are approved.

## Requirements and setup

- Ruby 3.2+
- PostgreSQL
- Rails 7.2

Install dependencies and prepare the database:

```sh
bundle install
bin/rails db:create db:migrate
```

GoodJob stores background jobs in PostgreSQL. It is configured as the Active Job adapter, and its recurring tasks dispatch the transactional payout outbox and mark abandoned submissions as `unknown`. Run the web server and a GoodJob worker in production:

```sh
bin/rails server
bundle exec good_job start
```

The generated `.env.example` lists supported environment variables. Dotenv loads `.env` in development and test; use your hosting secret manager in production. Prefer encrypted Rails credentials for long-lived secrets. Never commit actual keys or the B2C `SecurityCredential`.

## Daraja configuration

Set `MPESA_ENVIRONMENT` to `sandbox` or `production`, then configure the consumer key and secret, Paybill shortcode, approved B2C shortcode, initiator name, encrypted security credential, recipient phone in `2547XXXXXXXX` format, and public HTTPS callback URLs. Generate a random `MPESA_CALLBACK_TOKEN` with at least 32 characters and include it in every callback URL path; the controllers reject requests without the matching token.

`MPESA_B2C_ENABLED` and `MPESA_FUNDING_AVAILABLE` both default to `false`. Keep them false until Safaricom confirms that the shortcode/account arrangement can disburse funds and that working funds are available to B2C. A Paybill confirmation does not imply that the B2C utility account has been funded. The app never automatically retries a payout in `unknown` or `failed` state.

## Callback endpoints

Register the C2B confirmation URL with Daraja and provide the B2C result and timeout URLs on each B2C request:

```text
POST /webhooks/mpesa/c2b/:callback_token/confirmation
POST /webhooks/mpesa/b2c/:callback_token/result
POST /webhooks/mpesa/b2c/:callback_token/timeout
```

The C2B callback is durably recorded before it is acknowledged. A valid confirmation creates one payment keyed by the Safaricom receipt, an allocation, ledger entries, and an outbox event in a database transaction. Duplicate receipts do not create another payout. Invalid callbacks are retained as `needs_review` and logged without including their payload or secrets.

The recipient share rounds down for odd whole-shilling amounts; the retained share receives the remaining shilling. A zero recipient share does not create a zero-value B2C request.

## Payout safety and operations

Payouts move through `pending`, `submitting`, `processing`, `succeeded`, `failed`, `unknown`, or `awaiting_funds`. A worker claims the payout under a row lock, writes a stable originator conversation ID and attempt before the HTTP request, and refuses to pay a number different from the configured recipient. Request timeouts and interrupted submissions become `unknown`; they must be reconciled with Safaricom before any manual retry. Do not retry an uncertain B2C transfer with a new originator ID.

The result callback is idempotent and creates settlement ledger entries once. A timeout callback means the outcome is unknown, not that the transfer failed. Keep callback routes HTTPS-only in production, monitor `needs_review` callbacks and unknown payouts, and reconcile local payments and payout receipts against Safaricom's transaction records.

If the disbursement account is funded after payouts were left pending, queue the eligible payout again only after confirming it has never been submitted. For an `unknown` payout, first confirm its outcome with Safaricom; never requeue it blindly. Confirmed pending payouts can be queued with `bin/rails runner 'MpesaPayoutJob.perform_later(PAYOUT_ID)'`.

Download a Safaricom statement as a CSV with `receipt,amount` columns and compare it with local records using `KIND=c2b` or `KIND=b2c`:

```sh
KIND=c2b FILE=statement.csv SINCE=2026-10-21 UNTIL=2026-10-21 bin/rails mpesa:reconcile
KIND=b2c FILE=statement.csv SINCE=2026-10-21 UNTIL=2026-10-21 bin/rails mpesa:reconcile
```

The command reports transactions missing from either side and amount mismatches; it does not modify payment or payout state.

## Database tables

- `mpesa_payments`: confirmed incoming payments, unique by M-Pesa receipt.
- `split_allocations`: the retained and recipient shares.
- `mpesa_payouts`: payout state and Safaricom identifiers.
- `ledger_entries`: immutable accounting events with unique idempotency keys.
- `mpesa_callback_events`: callback inbox and review state.
- `mpesa_payout_attempts`: durable outbound request attempts.
- `mpesa_outbox_events`: payout work committed alongside payment allocation.

Production launch still depends on Safaricom approving the required C2B/B2C products, callback URLs, shortcode arrangement, and settlement/funding movement for the business.
