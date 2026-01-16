#!/usr/bin/env node

const https = require('https');
const fs = require('fs');
const path = require('path');
const os = require('os');

const CONFIG_DIR = path.join(os.homedir(), '.config', 'nf');
const CONFIG_FILE = path.join(CONFIG_DIR, 'config.json');

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  cyan: '\x1b[36m',
  dim: '\x1b[2m'
};

function loadConfig() {
  try {
    if (fs.existsSync(CONFIG_FILE)) {
      const data = fs.readFileSync(CONFIG_FILE, 'utf8');
      return JSON.parse(data);
    }
  } catch (err) {
    console.error(`${colors.red}Error loading config: ${err.message}${colors.reset}`);
  }
  return null;
}

function saveConfig(apiKey) {
  try {
    if (!fs.existsSync(CONFIG_DIR)) {
      fs.mkdirSync(CONFIG_DIR, { recursive: true });
    }
    fs.writeFileSync(CONFIG_FILE, JSON.stringify({ apiKey }, null, 2));
    console.log(`${colors.green}API key saved to ${CONFIG_FILE}${colors.reset}`);
  } catch (err) {
    console.error(`${colors.red}Error saving config: ${err.message}${colors.reset}`);
  }
}

function httpsGet(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    }).on('error', reject);
  });
}

async function getNutritionData(foodItem, apiKey, multiplier = 1) {
  const url = `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${encodeURIComponent(apiKey)}&query=${encodeURIComponent(foodItem)}&pageSize=1`;

  try {
    const data = await httpsGet(url);

    if (!data.foods || data.foods.length === 0) {
      return null;
    }

    const food = data.foods[0];
    let protein = 0;
    let carbs = 0;
    let fat = 0;

    if (food.foodNutrients) {
      food.foodNutrients.forEach(nutrient => {
        if (nutrient.nutrientId === 1003 || nutrient.nutrientName === 'Protein') {
          protein = nutrient.value || 0;
        }
        if (nutrient.nutrientId === 1005 || nutrient.nutrientName === 'Carbohydrate, by difference') {
          carbs = nutrient.value || 0;
        }
        if (nutrient.nutrientId === 1004 || nutrient.nutrientName === 'Total lipid (fat)') {
          fat = nutrient.value || 0;
        }
      });
    }

    return {
      name: food.description || foodItem,
      protein: Math.round(protein * multiplier),
      carbs: Math.round(carbs * multiplier),
      fat: Math.round(fat * multiplier)
    };
  } catch (err) {
    throw new Error(`Failed to fetch data: ${err.message}`);
  }
}

function showHelp() {
  console.log(`
${colors.cyan}nf - Nutrition Facts CLI Tool${colors.reset}

${colors.green}USAGE:${colors.reset}
  nf <quantity> <unit> <food_item>[, <quantity> <unit> <food_item2>, ...]
  nf <food_item> [food_item2] [food_item3] ...  (assumes 100g each)
  nf --setup <api_key>
  nf --help

${colors.green}EXAMPLES:${colors.reset}
  nf apple
  nf "chicken breast" rice broccoli
  nf 1 lb ground beef, 1 gal milk, 500 eggs
  nf 200g chicken breast, 1 cup rice
  nf --setup YOUR_API_KEY_HERE

${colors.green}UNITS:${colors.reset}
  Weight: g, lb, oz, kg
  Volume: cup, tbsp, tsp, ml, l, gal, qt, pt, fl_oz
  Special: egg, eggs (50g each)

${colors.green}SETUP:${colors.reset}
  1. Get a free API key from: https://fdc.nal.usda.gov/api-key-signup.html
  2. Run: nf --setup YOUR_API_KEY_HERE
  3. Start using: nf apple

${colors.dim}Your API key is stored in: ${CONFIG_FILE}${colors.reset}
`);
}

// Unit conversions to grams
const unitConversions = {
  g: 1,
  gram: 1,
  grams: 1,
  kg: 1000,
  kilogram: 1000,
  kilograms: 1000,
  lb: 453.592,
  lbs: 453.592,
  pound: 453.592,
  pounds: 453.592,
  oz: 28.3495,
  ounce: 28.3495,
  ounces: 28.3495,
  // Special cases
  egg: 50, // approximate average egg weight
  eggs: 50,
  // Volume conversions (approximate, assuming water density)
  cup: 240, // 240g for water
  cups: 240,
  tbsp: 15,
  tablespoon: 15,
  tablespoons: 15,
  tsp: 5,
  teaspoon: 5,
  teaspoons: 5,
  ml: 1,
  milliliter: 1,
  milliliters: 1,
  l: 1000,
  liter: 1000,
  liters: 1000,
  gal: 3785.41,
  gallon: 3785.41,
  gallons: 3785.41,
  qt: 946.353,
  quart: 946.353,
  quarts: 946.353,
  pt: 473.176,
  pint: 473.176,
  pints: 473.176,
  fl_oz: 29.5735,
  fluid_ounce: 29.5735,
  fluid_ounces: 29.5735,
};

function parseFoodItem(item) {
  const trimmed = item.trim();
  // Match number followed by the rest
  const match = trimmed.match(/^(\d+(?:\.\d+)?)\s*(.+)$/);
  if (!match) {
    // No quantity, assume 100g
    return { quantity: 100, unit: 'g', food: trimmed };
  }
  const [, qtyStr, rest] = match;
  const quantity = parseFloat(qtyStr);
  const restParts = rest.trim().split(/\s+/);
  const firstWord = restParts[0].toLowerCase();
  let unit = 'g';
  let food = rest;
  if (unitConversions.hasOwnProperty(firstWord)) {
    // First word is a unit
    unit = firstWord;
    food = restParts.slice(1).join(' ');
    if (!food.trim()) {
      // If no food after unit, assume unit is the food (e.g., 500 eggs)
      food = firstWord;
    }
  }
  return { quantity, unit, food: food.trim() };
}

function getGrams(quantity, unit) {
  const conversion = unitConversions[unit];
  if (!conversion) {
    throw new Error(`Unknown unit: ${unit}`);
  }
  return quantity * conversion;
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    showHelp();
    process.exit(0);
  }

  if (args[0] === '--setup') {
    if (args.length < 2) {
      console.error(`${colors.red}Error: Please provide an API key${colors.reset}`);
      console.log(`Usage: nf --setup YOUR_API_KEY`);
      process.exit(1);
    }
    saveConfig(args[1]);
    process.exit(0);
  }

  const config = loadConfig();
  if (!config || !config.apiKey) {
    console.error(`${colors.red}Error: No API key configured${colors.reset}`);
    console.log(`Run: ${colors.cyan}nf --setup YOUR_API_KEY${colors.reset}`);
    console.log(`Get a free API key at: ${colors.cyan}https://fdc.nal.usda.gov/api-key-signup.html${colors.reset}`);
    process.exit(1);
  }

  // Join all args and split on comma to handle multiple items
  const input = args.join(' ');
  const foodItems = input.split(',').map(s => s.trim()).filter(s => s);

  const results = [];
  let totalProtein = 0;
  let totalCarbs = 0;
  let totalFat = 0;

  for (const item of foodItems) {
    try {
      const { quantity, unit, food } = parseFoodItem(item);
      const grams = getGrams(quantity, unit);
      const multiplier = grams / 100;
      const result = await getNutritionData(food, config.apiKey, multiplier);
      if (result) {
        results.push(result);
        totalProtein += result.protein;
        totalCarbs += result.carbs;
        totalFat += result.fat;
        const qtyStr = quantity % 1 === 0 ? quantity.toString() : quantity.toFixed(2);
        console.log(`${colors.green}${qtyStr} ${unit} ${result.name}:${colors.reset} ${result.protein}g protein, ${result.carbs}g carbs, ${result.fat}g fat`);
      } else {
        console.log(`${colors.red}${item}: Not found${colors.reset}`);
      }
    } catch (err) {
      console.error(`${colors.red}${item}: ${err.message}${colors.reset}`);
    }
  }

  if (results.length > 1) {
    console.log(`${colors.dim}---${colors.reset}`);
    console.log(`${colors.yellow}Total: ${Math.round(totalProtein)}g protein, ${Math.round(totalCarbs)}g carbs, ${Math.round(totalFat)}g fat${colors.reset}`);
  }
}

main().catch(err => {
  console.error(`${colors.red}Error: ${err.message}${colors.reset}`);
  process.exit(1);
});
