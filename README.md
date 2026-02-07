# Clover Sandbox Simulator

A Ruby gem for simulating Point of Sale operations in Clover sandbox environments. Generates realistic orders, payments, and transaction data across **9 business types** for testing integrations with Clover's API.

## Features

- **9 Business Types**: Restaurant, Cafe/Bakery, Bar/Nightclub, Food Truck, Fine Dining, Pizzeria, Retail Clothing, Retail General, Salon/Spa — each with tailored categories and items
- **168 Menu/Product Items**: Spread across 38 categories with realistic pricing
- **Modifier Groups**: Temperature, add-ons, sides, dressings, drink sizes applied to menu items
- **Multiple Payment Methods**: Credit/Debit cards via Ecommerce API, plus Cash, Check, Gift Card, and other tenders
- **Split Payments**: Supports 1-4 tender splits per order, more common for larger parties
- **Meal Period Simulation**: Orders distributed across breakfast, lunch, happy hour, dinner, and late night with realistic weights
- **Order Types**: Dine-in, Takeout, and Delivery with configurable settings
- **Service Charges**: Auto-gratuity for large parties (18% for 6+ guests)
- **Dynamic Order Volume**: Different order counts for weekdays, Friday, Saturday, Sunday (40-120 orders/day)
- **Tips & Taxes**: Variable tip rates by dining option (15-25% dine-in, 0-15% takeout, 10-20% delivery)
- **Per-Item Tax Rates**: Different tax rates for food vs alcohol items
- **Discounts**: 7 discount types including Happy Hour, promo codes, loyalty, combo, line-item, threshold, and legacy
- **Employees & Customers**: Auto-generated with realistic names and contact info
- **Shift Tracking**: Clock in/out for employees with duration tracking
- **Cash Drawer Management**: Open/close drawer events with cash tracking
- **Party Size Variation**: 1-6 guests affecting item counts and split payment probability
- **Order Notes**: Random special instructions (allergies, modifications, VIP customers)
- **PostgreSQL Audit Trail**: Track all simulated orders, payments, and API requests in a local database
- **Daily Summaries**: Automated aggregation of revenue, tax, tips, and discounts by meal period and dining option
- **Database Seeding**: Idempotent FactoryBot-based seeder for all 9 business types

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'clover_sandbox_simulator'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install clover_sandbox_simulator
```

## Configuration

### Multi-Merchant Setup (Recommended)

Create a `.env.json` file with the object format:

```json
{
  "DATABASE_URL": "postgres://localhost:5432/clover_simulator_development",
  "merchants": [
    {
      "CLOVER_MERCHANT_ID": "YOUR_MERCHANT_ID",
      "CLOVER_MERCHANT_NAME": "My Test Merchant",
      "CLOVER_API_TOKEN": "static-api-token",
      "CLOVER_ACCESS_TOKEN": "oauth-jwt-token",
      "CLOVER_REFRESH_TOKEN": "clvroar-refresh-token",
      "PUBLIC_TOKEN": "ecommerce-public-token",
      "PRIVATE_TOKEN": "ecommerce-private-token"
    }
  ]
}
```

The legacy array format is also supported for backwards compatibility:

```json
[
  {
    "CLOVER_MERCHANT_ID": "YOUR_MERCHANT_ID",
    "CLOVER_API_TOKEN": "your-token"
  }
]
```

**Token Types:**
- `CLOVER_API_TOKEN` - Static API token (never expires, preferred)
- `CLOVER_ACCESS_TOKEN` - OAuth JWT token (expires, can be refreshed)
- `PUBLIC_TOKEN` / `PRIVATE_TOKEN` - Required for credit card payments via Ecommerce API
- `DATABASE_URL` - PostgreSQL connection string for audit trail persistence

### Single Merchant Setup

Alternatively, use a `.env` file:

```env
CLOVER_MERCHANT_ID=your_merchant_id
CLOVER_API_TOKEN=your_api_token
CLOVER_ENVIRONMENT=https://sandbox.dev.clover.com/
PUBLIC_TOKEN=your_ecommerce_public_token
PRIVATE_TOKEN=your_ecommerce_private_token
LOG_LEVEL=INFO
TAX_RATE=8.25
```

### Database Setup

The simulator uses PostgreSQL to persist audit data (simulated orders, payments, API requests, daily summaries). Set up the database with:

```bash
# Create, migrate, and seed the database
./bin/simulate db reset

# Or step by step:
./bin/simulate db create
./bin/simulate db migrate
./bin/simulate db seed
```

## Usage

### Quick Start

Run a full simulation (setup + generate orders):

```bash
./bin/simulate full
```

### Commands

```bash
# Show version
./bin/simulate version

# List available merchants from .env.json
./bin/simulate merchants

# Set up restaurant entities (categories, items, discounts, etc.)
./bin/simulate setup

# Generate orders for today (random count based on day of week)
./bin/simulate generate

# Generate a specific number of orders
./bin/simulate generate -n 25

# Generate orders with refunds (5% default, customize with -r)
./bin/simulate generate -n 25 -r 10

# Generate a realistic full day of restaurant operations
./bin/simulate day

# Generate a busy day (2x normal volume)
./bin/simulate day -x 2.0

# Generate a slow day (0.5x normal volume)
./bin/simulate day -x 0.5

# Generate a lunch or dinner rush
./bin/simulate rush -p lunch -n 20
./bin/simulate rush -p dinner -n 30

# Run full simulation (setup + orders)
./bin/simulate full

# Check current status (all entities)
./bin/simulate status

# Use a specific merchant by index or ID
./bin/simulate status -i 0
./bin/simulate generate -m YOUR_MERCHANT_ID

# Gift card operations
./bin/simulate gift_cards                    # List all gift cards
./bin/simulate gift_card_create -a 5000      # Create $50 gift card
./bin/simulate gift_card_balance -i CARD_ID  # Check balance
./bin/simulate gift_card_reload -i CARD_ID -a 2500  # Add $25
./bin/simulate gift_card_redeem -i CARD_ID -a 1000  # Use $10

# Refund operations
./bin/simulate refunds                       # List all refunds
./bin/simulate refund -p PAYMENT_ID          # Full refund
./bin/simulate refund -p PAYMENT_ID -a 500   # Partial refund ($5)

# Inventory & Modifiers
./bin/simulate modifier_groups               # List modifier groups
./bin/simulate tax_rates                     # List tax rates

# Order Types & Service Charges
./bin/simulate order_types                   # List order types (Dine In, Takeout, etc.)
./bin/simulate service_charges               # List service charges

# Shift Management
./bin/simulate shifts                        # List active shifts
./bin/simulate shift_clock_in -e EMP_ID      # Clock in an employee
./bin/simulate shift_clock_out -e EMP_ID     # Clock out an employee

# Cash Drawer Operations
./bin/simulate cash_open_drawer -a 10000     # Open drawer with $100 starting cash
./bin/simulate cash_close_drawer -e EMP_ID   # Close drawer for employee

# List recent orders
./bin/simulate orders
./bin/simulate orders -l 50              # Show 50 orders

# Reset orders (delete all orders, keep menu/employees)
./bin/simulate reset_orders --confirm    # Delete today's orders
./bin/simulate reset_orders --confirm --no-today-only  # Delete ALL orders

# Delete all entities (requires confirmation)
./bin/simulate delete --confirm

# Enable verbose logging
./bin/simulate generate -v
```

### Database Management

```bash
# Database subcommands
./bin/simulate db create    # Create PostgreSQL database
./bin/simulate db migrate   # Run pending migrations
./bin/simulate db seed      # Seed with 9 business types, 38 categories, 168 items
./bin/simulate db reset     # Drop, create, migrate, and seed

# Reporting
./bin/simulate summary         # Show daily summary (revenue, orders, tips, tax)
./bin/simulate audit            # Show recent API requests
./bin/simulate business_types   # List business types with category/item counts
```

## Business Types

The simulator supports 9 business types across 3 industries:

| Business Type | Industry | Categories | Items | Description |
|---------------|----------|------------|-------|-------------|
| Restaurant | Food | 5 | 25 | Full-service casual dining |
| Cafe/Bakery | Food | 5 | 25 | Coffee shop with pastries and light fare |
| Bar/Nightclub | Food | 5 | 25 | Craft cocktails, draft beer, late-night bites |
| Food Truck | Food | 3 | 15 | Mobile street food — tacos and Mexican fare |
| Fine Dining | Food | 3 | 15 | Upscale prix-fixe and a la carte dining |
| Pizzeria | Food | 3 | 15 | Classic and specialty pies, calzones, sides |
| Retail Clothing | Retail | 5 | 25 | Casual wear with size/color variants |
| Retail General | Retail | 5 | 13 | Electronics, home goods, personal care |
| Salon/Spa | Service | 4 | 10 | Hair salon, spa treatments, nail services |

All business types have tailored order profiles, category structures, and item pricing.

## Menu Structure

### Categories (Restaurant Example)
- Appetizers
- Entrees
- Sides
- Desserts
- Drinks
- Alcoholic Beverages
- Specials

### Sample Items

| Category | Item | Price |
|----------|------|-------|
| Appetizers | Buffalo Wings | $12.99 |
| Appetizers | Loaded Nachos | $10.99 |
| Entrees | Classic Burger | $14.99 |
| Entrees | NY Strip Steak | $28.99 |
| Entrees | Grilled Salmon | $21.99 |
| Sides | French Fries | $4.99 |
| Desserts | Cheesecake | $7.99 |
| Drinks | Soft Drink | $2.99 |
| Alcoholic | Draft Beer | $5.99 |

### Modifier Groups

| Group | Options | Example Use |
|-------|---------|-------------|
| Temperature | Rare, Medium Rare, Medium, Medium Well, Well Done | Steaks, Burgers |
| Add-Ons | Extra Cheese (+$1.50), Bacon (+$2.00), Avocado (+$1.75) | Burgers, Sandwiches |
| Side Choice | French Fries, Sweet Potato Fries, Onion Rings, Salad | Entrees |
| Dressing | Ranch, Blue Cheese, Caesar, Balsamic, Honey Mustard | Salads |
| Drink Size | Small, Medium, Large | Beverages |

## Payment Methods

### Credit/Debit Card Payments (Ecommerce API)

Credit and debit card payments are fully supported via the **Clover Ecommerce API**. This requires configuring `PUBLIC_TOKEN` and `PRIVATE_TOKEN` in your `.env.json`.

~55% of orders use card payments when the Ecommerce API is configured. The simulator tokenizes test cards and creates charges linked to orders. If a charge fails, payment gracefully falls back to cash.

**Test Card Numbers:**

| Card Type | Number |
|-----------|--------|
| Visa | 4242424242424242 |
| Visa Debit | 4005562231212123 |
| Mastercard | 5200828282828210 |
| Amex | 378282246310005 |
| Discover | 6011111111111117 |
| Decline (test) | 4000000000000002 |
| Insufficient Funds (test) | 4000000000009995 |

**Ecommerce API Endpoints:**
- Tokenization: `https://token-sandbox.dev.clover.com/v1/tokens`
- Charges: `https://scl-sandbox.dev.clover.com/v1/charges`
- Refunds: `https://scl-sandbox.dev.clover.com/v1/refunds`

### Platform API Tenders

For non-card payments, the simulator uses Platform API tenders:
- Cash (preferred for orders under $20)
- Check
- Gift Card
- External Payment

The simulator uses whatever tenders are available in the Clover merchant account. Card tenders are automatically excluded from split payments (which use the Platform API).

## Audit Trail & Persistence

The simulator persists all activity to a PostgreSQL database for analysis and debugging:

### Models

| Model | Purpose |
|-------|---------|
| `BusinessType` | 9 business types with industry classification and order profiles |
| `Category` | 38 categories linked to business types with tax groups |
| `Item` | 168 items with SKUs, pricing, and optional size/color variants |
| `SimulatedOrder` | Every generated order with merchant ID, period, dining option, amounts |
| `SimulatedPayment` | Payment records with tender type classification (credit_card, debit_card, cash, check, gift_card) |
| `ApiRequest` | Full audit log of every HTTP call to Clover (method, URL, status, duration, payloads) |
| `DailySummary` | Automated daily aggregation of revenue, tax, tips, and discounts |

### Daily Summary

The `DailySummary` model automatically aggregates:
- Order count, revenue, tax, tips, discounts
- Breakdown by meal period and dining option
- Revenue by meal period and dining option
- Payment breakdown by tender type

```ruby
# Generate a summary for today
DailySummary.generate_for!("MERCHANT_ID", Date.today)

# Query summaries
DailySummary.for_merchant("M1").recent(7)
DailySummary.between_dates(1.week.ago, Date.today)
```

## Tax Rates

The simulator supports per-item tax rates based on category:

| Category | Tax Rate | Notes |
|----------|----------|-------|
| Food Items | 8.25% | Standard sales tax |
| Alcoholic Beverages | 8.25% + 10% | Sales tax + alcohol tax |

Tax rates are automatically assigned to items during setup based on their category.

## Service Charges

### Auto-Gratuity

Large parties (6+ guests) automatically receive an 18% auto-gratuity service charge. This is:
- Added to the order subtotal before payment
- Displayed as a separate line item
- Configurable via the `ServiceChargeService`

**Note:** Service charges must be pre-configured in the Clover dashboard for sandbox environments, as the API may not support creating them dynamically.

## Order Types

The simulator supports multiple order types that affect order flow and reporting:

| Order Type | Description |
|------------|-------------|
| Dine In | In-restaurant dining |
| Takeout | Customer pickup |
| Delivery | Delivery orders |
| Online | Online/web orders |
| Catering | Large catering orders |

Order types are automatically created during setup if they don't exist.

## Tips

Tips vary by dining option to simulate realistic customer behavior:

| Dining Option | Min Tip | Max Tip |
|---------------|---------|---------|
| Dine-In (HERE) | 15% | 25% |
| To-Go | 0% | 15% |
| Delivery | 10% | 20% |

- Large parties (6+) automatically receive 18% auto-gratuity
- Split payments divide tips proportionally across tenders

## Order Patterns

### Daily Volume

| Day | Min Orders | Max Orders |
|-----|------------|------------|
| Weekday | 40 | 60 |
| Friday | 70 | 100 |
| Saturday | 80 | 120 |
| Sunday | 50 | 80 |

### Meal Periods

Orders are distributed across realistic meal periods with weighted distribution:

| Period | Hours | Weight | Avg Items | Avg Party Size |
|--------|-------|--------|-----------|----------------|
| Breakfast | 7-10 AM | 15% | 2-4 | 1-2 |
| Lunch | 11 AM-2 PM | 30% | 2-5 | 1-4 |
| Happy Hour | 3-5 PM | 10% | 2-4 | 2-4 |
| Dinner | 5-9 PM | 35% | 3-6 | 2-6 |
| Late Night | 9-11 PM | 10% | 2-4 | 1-3 |

### Dining Options

Each meal period has different dining option distributions:

| Period | Dine-In | To-Go | Delivery |
|--------|---------|-------|----------|
| Breakfast | 40% | 50% | 10% |
| Lunch | 35% | 45% | 20% |
| Happy Hour | 80% | 15% | 5% |
| Dinner | 70% | 15% | 15% |
| Late Night | 50% | 30% | 20% |

## Architecture

```
clover_sandbox_simulator/
├── bin/simulate                      # CLI entry point (Thor)
├── lib/
│   ├── clover_sandbox_simulator.rb   # Gem entry point, VERSION constant
│   └── clover_sandbox_simulator/
│       ├── configuration.rb          # Multi-merchant config from .env.json
│       ├── database.rb               # PostgreSQL connection management
│       ├── seeder.rb                 # Idempotent FactoryBot seeder
│       ├── parallel_executor.rb      # Concurrent execution support
│       ├── models/                   # ActiveRecord models (standalone, no Rails)
│       │   ├── record.rb            # Base class for all models
│       │   ├── business_type.rb     # 9 business types with industries
│       │   ├── category.rb          # 38 categories per business type
│       │   ├── item.rb              # 168 items with pricing & variants
│       │   ├── simulated_order.rb   # Generated order audit records
│       │   ├── simulated_payment.rb # Payment audit records by tender type
│       │   ├── api_request.rb       # Full HTTP request/response audit log
│       │   └── daily_summary.rb     # Automated daily aggregation
│       ├── db/
│       │   ├── migrate/             # 8 PostgreSQL migrations (UUID PKs)
│       │   └── factories/           # FactoryBot factories (shared with seeder)
│       ├── services/
│       │   ├── base_service.rb      # HTTP client, error handling, audit logging
│       │   └── clover/              # Clover API services
│       │       ├── inventory_service.rb    # Categories, items, modifier groups
│       │       ├── order_service.rb        # Orders, line items, modifiers
│       │       ├── payment_service.rb      # Payments, splits, card payments
│       │       ├── tender_service.rb       # Payment tenders, card detection
│       │       ├── ecommerce_service.rb    # Card tokenization & charges
│       │       ├── tax_service.rb          # Tax rates, per-item taxes
│       │       ├── discount_service.rb     # Discounts, promos, combos, loyalty
│       │       ├── employee_service.rb     # Employee management
│       │       ├── customer_service.rb     # Customer management
│       │       ├── refund_service.rb       # Full/partial refunds
│       │       ├── gift_card_service.rb    # Gift card management
│       │       ├── service_charge_service.rb # Service charges, auto-gratuity
│       │       ├── shift_service.rb        # Employee shifts, clock in/out
│       │       ├── order_type_service.rb   # Order types (Dine In, Takeout, etc.)
│       │       ├── cash_event_service.rb   # Cash drawer operations
│       │       ├── oauth_service.rb        # Token refresh
│       │       └── services_manager.rb     # Thread-safe service access
│       ├── generators/
│       │   ├── data_loader.rb        # DB-first data loading with JSON fallback
│       │   ├── entity_generator.rb   # Setup entities (idempotent)
│       │   └── order_generator.rb    # Generate realistic orders & payments
│       └── data/
│           └── restaurant/           # JSON data files (fallback for DB)
│               ├── categories.json
│               ├── items.json
│               ├── discounts.json
│               ├── tenders.json
│               ├── modifiers.json
│               └── tax_rates.json
└── spec/                             # 1124 examples, 0 failures
```

## Development

```bash
# Run all tests
bundle exec rspec

# Run tests with documentation format
bundle exec rspec --format documentation

# Run specific test file
bundle exec rspec spec/services/clover/tender_service_spec.rb

# Run model specs
bundle exec rspec spec/models/

# Run integration tests (requires .env.json with valid credentials)
bundle exec rspec spec/integration/

# Run linter
bundle exec rubocop

# Open console
bundle exec irb -r ./lib/clover_sandbox_simulator

# Build the gem
gem build clover_sandbox_simulator.gemspec
```

## Testing

The gem includes comprehensive RSpec tests with WebMock for HTTP stubbing, VCR for integration tests, and DatabaseCleaner for test isolation.

### Test Coverage

- **1124 examples, 0 failures, 3 pending**
- Database connection management and migration
- Seeder idempotency (9 business types, 38 categories, 168 items)
- FactoryBot factory validation (219 factories/traits)
- All ActiveRecord models (validations, scopes, associations)
- All Clover API services:
  - InventoryService (categories, items, modifier groups)
  - OrderService (create, line items, dining options, modifiers)
  - PaymentService (single, split, and card payments)
  - TenderService (tender selection, card detection, ecommerce filtering)
  - EcommerceService (tokenization, charges, refunds)
  - TaxService (rates, per-item calculation, item associations)
  - DiscountService (percentage, fixed, time-based, loyalty, combo, promo codes)
  - EmployeeService (CRUD, deterministic setup)
  - CustomerService (CRUD, anonymous orders)
  - RefundService (full/partial refunds, multiple strategies)
  - GiftCardService (create, reload, redeem)
  - ServiceChargeService (auto-gratuity, apply to orders)
  - ShiftService (clock in/out, active shifts)
  - OrderTypeService (CRUD, default setup)
  - CashEventService (drawer operations, simulated responses)
  - ServicesManager (thread-safe memoization, lazy loading)
- Audit trail (API request logging, order/payment tracking, daily summaries)
- Order generator (meal periods, dining options, tips, card payments, fallbacks, refunds, modifiers, service charges)
- Data loader (DB-first with JSON fallback, format parity)
- Multi-business type integration (industry classification, order profiles)
- Financial data quality validation
- Edge cases (nil handling, empty arrays, API errors, network failures)
- VCR integration tests for real API validation

### Test Files

```
spec/
├── audit_logging_spec.rb              # BaseService audit + OrderGenerator tracking
├── configuration_spec.rb              # Multi-merchant config validation
├── configuration_database_url_spec.rb # DATABASE_URL parsing
├── database_spec.rb                   # Connection management, migrations
├── seeder_spec.rb                     # Idempotent seeding, business types
├── factories/
│   └── factories_spec.rb             # 219 factory/trait validation
├── generators/
│   ├── data_loader_spec.rb           # DB/JSON loading, format parity
│   ├── entity_generator_spec.rb      # Idempotent setup
│   └── order_generator_spec.rb       # Payments, tips, dining, card flow
├── integration/
│   ├── audit_trail_spec.rb           # End-to-end order/payment/summary
│   ├── data_loader_compat_spec.rb    # DB vs JSON compatibility
│   ├── multi_business_spec.rb        # 9 business types, industries
│   ├── modifier_groups_spec.rb       # VCR: real API
│   ├── service_charges_spec.rb       # VCR: real API
│   ├── order_types_spec.rb           # VCR: real API
│   ├── cash_events_spec.rb           # VCR: real API
│   └── tax_rates_spec.rb            # VCR: real API
├── models/
│   ├── api_request_spec.rb           # Scopes, validations
│   ├── business_type_spec.rb         # Industries, associations
│   ├── category_spec.rb              # Scoped uniqueness
│   ├── daily_summary_spec.rb         # Aggregation, idempotency
│   ├── item_spec.rb                  # Pricing, variants, scopes
│   ├── record_spec.rb                # Base class
│   ├── simulated_order_spec.rb       # Status transitions, scopes
│   └── simulated_payment_spec.rb     # Tender classification, scopes
└── services/clover/
    ├── cash_event_service_spec.rb
    ├── customer_service_spec.rb
    ├── discount_service_spec.rb
    ├── employee_service_spec.rb
    ├── financial_data_quality_spec.rb
    ├── gift_card_service_spec.rb
    ├── inventory_service_spec.rb
    ├── order_service_spec.rb
    ├── order_type_service_spec.rb
    ├── payment_service_spec.rb
    ├── refund_service_spec.rb
    ├── service_charge_service_spec.rb
    ├── services_manager_spec.rb
    ├── shift_service_spec.rb
    ├── tax_service_spec.rb
    └── tender_service_spec.rb
```

### Idempotency Verification

All setup operations are idempotent - running them multiple times will not create duplicates:

```ruby
# This is safe to run multiple times
generator = CloverSandboxSimulator::Generators::EntityGenerator.new
generator.setup_all # First run: creates entities
generator.setup_all # Second run: skips existing, returns same results
```

The tests verify:
- Categories are not duplicated (case-insensitive matching)
- Items are not duplicated (case-insensitive matching)
- Discounts are not duplicated (case-insensitive matching)
- Modifier groups AND their child modifiers are not duplicated
- Tax rates are not duplicated
- Order types are not duplicated
- Employees/customers only created if count threshold not met
- Database seeder is idempotent across all 9 business types

## Sandbox Limitations

Some Clover sandbox operations may return errors or behave differently than production:

| Feature | Sandbox Support | Notes |
|---------|-----------------|-------|
| Service Charge Creation | Limited | Must pre-configure in dashboard |
| Cash Event Creation | Limited | Returns 405, simulated locally |
| Item Tax Rate Fetch | Limited | Returns 405, simulated locally |
| Credit Card Payments | Full | Via Ecommerce API |
| Order Creation | Full | Today's date only |

The simulator handles these limitations gracefully with fallback behavior.

## Clover API Notes

- **Sandbox URL**: `https://sandbox.dev.clover.com/`
- **API Version**: v3
- **Authentication**: Bearer token (OAuth) for Platform API; apikey header for tokenization
- **Date Limitation**: Clover sandbox only allows creating orders for TODAY
- **Ecommerce API**: Separate endpoints for card tokenization, charges, and refunds

## License

MIT License
