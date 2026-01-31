# Clover Sandbox Simulator

A Ruby gem for simulating Point of Sale operations in Clover sandbox environments. Generates realistic restaurant orders, payments, and transaction data for testing integrations with Clover's API.

## Features

- **Realistic Restaurant Data**: Complete menu with 39 items across 7 categories (appetizers, entrees, sides, desserts, drinks, alcoholic beverages, specials)
- **Safe Sandbox Payments**: Uses Cash, Check, Gift Card, and other safe tenders (avoids broken Credit/Debit cards in Clover sandbox)
- **Split Payments**: Supports 1-4 tender splits per order, more common for larger parties
- **Meal Period Simulation**: Orders distributed across breakfast, lunch, happy hour, dinner, and late night with realistic weights
- **Dining Options**: Dine-in, To-Go, and Delivery with period-appropriate distributions
- **Dynamic Order Volume**: Different order counts for weekdays, Friday, Saturday, Sunday (40-120 orders/day)
- **Tips & Taxes**: Variable tip rates by dining option (15-25% dine-in, 0-15% takeout, 10-20% delivery)
- **Discounts**: 7 discount types including Happy Hour, Senior, Military, Employee, Birthday, and fixed amounts
- **Employees & Customers**: Auto-generated with realistic names and contact info
- **Party Size Variation**: 1-6 guests affecting item counts and split payment probability
- **Order Notes**: Random special instructions (allergies, modifications, VIP customers)

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

Copy the sample environment file and configure your Clover credentials:

```bash
cp .env.sample .env
```

Edit `.env` with your Clover sandbox credentials:

```env
CLOVER_MERCHANT_ID=your_merchant_id
CLOVER_API_TOKEN=your_api_token
CLOVER_ENVIRONMENT=https://sandbox.dev.clover.com/
LOG_LEVEL=INFO
TAX_RATE=8.25
```

## Usage

### Quick Start

Run a full simulation (setup + generate orders):

```bash
./bin/simulate full
```

### Commands

```bash
# Set up restaurant entities (categories, items, discounts, etc.)
./bin/simulate setup

# Generate orders for today (random count based on day of week)
./bin/simulate generate

# Generate a specific number of orders
./bin/simulate generate -n 25

# Generate a realistic full day of restaurant operations
./bin/simulate day

# Generate a busy day (2x normal volume)
./bin/simulate day -m 2.0

# Generate a slow day (0.5x normal volume)
./bin/simulate day -m 0.5

# Generate a lunch or dinner rush
./bin/simulate rush -p lunch -n 20
./bin/simulate rush -p dinner -n 30

# Run full simulation (setup + orders)
./bin/simulate full

# Check current status
./bin/simulate status

# Delete all entities (requires confirmation)
./bin/simulate delete --confirm

# Enable verbose logging
./bin/simulate generate -v
```

## Menu Structure

### Categories
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

## Payment Tenders

**IMPORTANT**: Credit Card and Debit Card are **broken** in Clover sandbox. This gem intentionally avoids them.

Safe tenders used:
- Cash (preferred for orders under $20)
- Check
- Gift Card
- External Payment
- Mobile Payment
- Store Credit

The simulator uses whatever safe tenders are available in the Clover merchant account.

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
├── bin/simulate                      # CLI entry point
├── lib/
│   ├── clover_sandbox_simulator.rb   # Gem entry point
│   └── clover_sandbox_simulator/
│       ├── configuration.rb          # Environment config
│       ├── services/
│       │   ├── base_service.rb
│       │   └── clover/               # Clover API services
│       │       ├── inventory_service.rb
│       │       ├── order_service.rb
│       │       ├── payment_service.rb
│       │       ├── tender_service.rb
│       │       ├── tax_service.rb
│       │       ├── discount_service.rb
│       │       ├── employee_service.rb
│       │       ├── customer_service.rb
│       │       └── services_manager.rb
│       ├── generators/
│       │   ├── data_loader.rb
│       │   ├── entity_generator.rb
│       │   └── order_generator.rb
│       └── data/
│           └── restaurant/           # JSON data files
│               ├── categories.json
│               ├── items.json
│               ├── discounts.json
│               ├── tenders.json
│               └── modifiers.json
└── spec/                             # RSpec tests
```

## Development

```bash
# Run all tests
bundle exec rspec

# Run tests with documentation format
bundle exec rspec --format documentation

# Run specific test file
bundle exec rspec spec/services/clover/tender_service_spec.rb

# Run linter
bundle exec rubocop

# Open console
bundle exec irb -r ./lib/clover_sandbox_simulator
```

## Testing

The gem includes comprehensive RSpec tests with WebMock for HTTP stubbing.

### Test Coverage

- **268 examples, 0 failures**
- Configuration validation
- Data loading from JSON files
- All Clover API services:
  - InventoryService (categories, items)
  - OrderService (create, line items, dining options)
  - PaymentService (single and split payments)
  - TenderService (safe tenders, split selection)
  - TaxService (rates, calculation)
  - DiscountService (percentage and fixed)
  - EmployeeService (CRUD, random selection)
  - CustomerService (CRUD, anonymous orders)
  - ServicesManager (memoization, lazy loading)
- Entity generator idempotency
- Order generator (meal periods, dining options, tips)
- Edge cases (nil handling, empty arrays, API errors)

### Test Files

```
spec/
├── configuration_spec.rb
├── generators/
│   ├── data_loader_spec.rb
│   ├── entity_generator_spec.rb
│   └── order_generator_spec.rb
└── services/clover/
    ├── customer_service_spec.rb
    ├── discount_service_spec.rb
    ├── employee_service_spec.rb
    ├── inventory_service_spec.rb
    ├── order_service_spec.rb
    ├── payment_service_spec.rb
    ├── services_manager_spec.rb
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
- Categories are not duplicated
- Items are not duplicated
- Discounts are not duplicated
- Employees/customers only created if count threshold not met

## Clover API Notes

- **Sandbox URL**: `https://sandbox.dev.clover.com/`
- **API Version**: v3
- **Authentication**: Bearer token (OAuth)
- **Date Limitation**: Clover sandbox only allows creating orders for TODAY

## License

MIT License
