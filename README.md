# POS Simulator

A clean Ruby gem for simulating Point of Sale operations in Clover sandbox environments. Generates realistic orders, payments, and transaction data for testing accounting integrations.

## Features

- **Realistic Restaurant Data**: Complete menu with appetizers, entrees, sides, desserts, drinks, and alcoholic beverages
- **Safe Sandbox Payments**: Uses Cash, Check, Gift Card, External Payment, Mobile Payment, Store Credit (avoids broken Credit/Debit cards)
- **Split Payments**: Supports 1-3 tender splits per order
- **Realistic Patterns**: Different order counts for weekdays, Friday, Saturday, Sunday
- **Tips & Taxes**: Automatic tip generation (15-25%) and tax calculation
- **Discounts**: Percentage and fixed-amount discounts
- **Employees & Customers**: Auto-generated with realistic data

## Installation

```bash
cd pos_simulator
bundle install
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

# Generate orders for today
./bin/simulate generate

# Generate a specific number of orders
./bin/simulate generate -n 25

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
- Cash (30% weight)
- Check (5% weight)
- Gift Card (15% weight)
- External Payment (10% weight)
- Mobile Payment (20% weight)
- Store Credit (10% weight)

## Order Patterns

| Day | Min Orders | Max Orders |
|-----|------------|------------|
| Weekday | 15 | 25 |
| Friday | 25 | 40 |
| Saturday | 30 | 50 |
| Sunday | 20 | 35 |

## Architecture

```
pos_simulator/
├── bin/simulate              # CLI entry point
├── lib/
│   ├── pos_simulator.rb      # Gem entry point
│   └── pos_simulator/
│       ├── configuration.rb  # Environment config
│       ├── services/
│       │   ├── base_service.rb
│       │   └── clover/       # Clover API services
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
│           └── restaurant/   # JSON data files
│               ├── categories.json
│               ├── items.json
│               ├── discounts.json
│               ├── tenders.json
│               └── modifiers.json
└── spec/                     # RSpec tests
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
bundle exec irb -r ./lib/pos_simulator
```

## Testing

The gem includes comprehensive RSpec tests with WebMock for HTTP stubbing and VCR for recording API interactions.

### Test Coverage

- **48 examples, 0 failures**
- Configuration validation
- Data loading from JSON files
- Clover API services (inventory, tender, order, payment)
- Entity generator idempotency
- Split payment calculations

### Idempotency Verification

All setup operations are idempotent - running them multiple times will not create duplicates:

```ruby
# This is safe to run multiple times
generator = PosSimulator::Generators::EntityGenerator.new
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
