# nf - Nutrition Facts CLI

A fast command-line tool to get macronutrient information for any food using the USDA FoodData Central API.

## Features

- 🚀 Fast and lightweight - no dependencies
- 🍎 Access to 400,000+ foods from USDA database
- 📊 Get protein, carbs, and fat information instantly
- 🎨 Color-coded terminal output
- 🔒 Secure API key storage in `~/.config/nf/`

## Installation

### Prerequisites

- Node.js (v12 or higher)
- A free USDA FoodData Central API key

### Quick Install

```bash
# Clone the repository
git clone https://github.com/NikoStapczynski/nutrition-facts.git
cd nutrition-facts

# Make the script executable
chmod +x nf

# Move to your PATH (choose one)
sudo mv nf /usr/local/bin/nf
# OR for user-only install:
mkdir -p ~/.local/bin
mv nf ~/.local/bin/nf
```

### Get Your Free API Key

1. Visit [USDA FoodData Central API signup](https://fdc.nal.usda.gov/api-key-signup.html)
2. Fill out the form (name, email, organization)
3. Copy your API key
4. Configure nf: `nf --setup YOUR_API_KEY_HERE`

## Usage

```bash
# Single food (assumes 100g)
nf apple

# Multiple foods (shows totals, assumes 100g each)
nf chicken breast rice broccoli

# Foods with spaces (use quotes)
nf "sweet potato" "peanut butter"

# Foods with quantities and units
nf 1 lb ground beef, 1 gal milk, 500 eggs

# Mixed formats
nf apple, 200g chicken breast, 1 cup rice

# View help
nf --help
```

### Supported Units

- **Weight**: g, lb, oz, kg
- **Volume**: cup, tbsp, tsp, ml, l, gal, qt, pt, fl_oz
- **Special**: egg, eggs (50g each)

### Example Output

```
$ nf apple banana
Apples, raw, with skin (Includes foods for USDA's Food Distribution Program): 0g protein, 14g carbs, 0g fat
Bananas, raw: 1g protein, 23g carbs, 0g fat
---
Total: 1g protein, 37g carbs, 0g fat

$ nf 1 lb ground beef, 500 eggs
1 lb Beef, ground, 80% lean meat / 20% fat, patty, cooked, broiled: 130g protein, 0g carbs, 67g fat
500 eggs Eggs, Grade A, Large, egg whole: 325g protein, 25g carbs, 350g fat
---
Total: 455g protein, 25g carbs, 417g fat
```

## Configuration

Your API key is stored in `~/.config/nf/config.json`

To reconfigure:
```bash
nf --setup NEW_API_KEY
```

## License

GPL-3.0 License - see [LICENSE](LICENSE) file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Author

Niko Stapczynski

## Acknowledgments

- Nutrition data provided by [USDA FoodData Central](https://fdc.nal.usda.gov/)
